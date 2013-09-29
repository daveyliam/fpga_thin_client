/*
Modified sdl.c from QEMU

Sends video data over ethernet to the FPGA thin client.
Receives and processes keyboard scancodes.

The ethernet MAC address to send to is hard coded.
*/

#ifndef _WIN32
#include <signal.h>
#endif

#include "qemu-common.h"
#include "console.h"
#include "sysemu.h"
#include "x_keymap.h"
#include "sdl_zoom.h"

#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_arp.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static DisplayChangeListener *dcl;

// raw ethernet socket variables and functions

#define ETHTERM_TYPE (0x88b5)
#define ETHTERM_PIXELS_PER_FRAME (320)

const char ethterm_mac_dst[] = "\x00\x50\x56\xab\xcd\xef";
static int ethterm_s = -1;
static struct sockaddr_ll ethterm_sockaddr;
char * ethterm_s_buf = NULL;
char * ethterm_r_buf = NULL;

int ethterm_init(const char * if_name);
void ethterm_cleanup(void);

// ps2 to xt conversion

uint8_t ps2toxt[128] = {0x00, 0x43, 0x00, 0x3F, 0x3D, 0x3B, 0x3C, 0x58, 0x00, 0x44, 0x42, 0x40, 0x3E, 0x0F, 0x29, 0x00, \
						0x00, 0x38, 0x2A, 0x00, 0x1D, 0x10, 0x02, 0x00, 0x00, 0x00, 0x2C, 0x1F, 0x1E, 0x11, 0x03, 0x5B, \
						0x00, 0x2E, 0x2D, 0x20, 0x12, 0x05, 0x04, 0x00, 0x00, 0x39, 0x2F, 0x21, 0x14, 0x13, 0x06, 0x5D, \
						0x00, 0x31, 0x30, 0x23, 0x22, 0x15, 0x07, 0x5C, 0x00, 0x00, 0x32, 0x24, 0x16, 0x08, 0x09, 0x00, \
						0x00, 0x33, 0x25, 0x17, 0x18, 0x0B, 0x0A, 0x00, 0x00, 0x34, 0x35, 0x26, 0x27, 0x19, 0x0C, 0x00, \
						0x00, 0x00, 0x28, 0x00, 0x1A, 0x0D, 0x00, 0x00, 0x3A, 0x36, 0x1C, 0x1B, 0x00, 0x2B, 0x00, 0x00, \
						0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0E, 0x00, 0x00, 0x4F, 0x00, 0x4B, 0x47, 0x00, 0x00, 0x00, \
						0x52, 0x53, 0x50, 0x00, 0x4D, 0x48, 0x01, 0x00, 0x00, 0x00, 0x51, 0x00, 0x00, 0x49, 0x00, 0x00};

// create a new raw ethernet socket.
// it fills a sockaddr structure with information about
// a given interface. it uses two ioctl calls, SIOCGIFINDEX and
// SIOCGIFHWADDR, to get the interfaces index number and hardware
// address.
// it takes a pointer to the sockaddr structure, the socket to use,
// and the interface name (as a string) as arguments.
// it returns 0 for success, or a non-zero integer for failure.
int ethterm_init(const char * if_name)
{
	struct ifreq ifr;
	
	// create a raw ethernet socket
	if((ethterm_s = socket(AF_PACKET, SOCK_RAW, htons(ETHTERM_TYPE))) == -1)
		return 1;

	// get the socket flags and then set the non-blocking flag
	//flags = fcntl(ethterm_s, F_GETFL, 0);
	//fcntl(ethterm_s, F_SETFL, flags | O_NONBLOCK);

	// copy the given interface name to the ifr structure
	strncpy(ifr.ifr_name, if_name, IFNAMSIZ);
	
	// get the interface index
	if(ioctl(ethterm_s, SIOCGIFINDEX, &ifr) == -1)
	{
		close(ethterm_s);
		ethterm_s = -1;
		return 1;
	}
	
	// fill the sockaddr structure
	ethterm_sockaddr.sll_ifindex = ifr.ifr_ifindex;
	ethterm_sockaddr.sll_family = AF_PACKET;
	ethterm_sockaddr.sll_protocol = htons(ETHTERM_TYPE);
	ethterm_sockaddr.sll_hatype = ARPHRD_ETHER;
	ethterm_sockaddr.sll_pkttype = PACKET_OTHERHOST;
	ethterm_sockaddr.sll_halen = ETH_ALEN;
	
	// get the interface hardware (mac) address
	if(ioctl(ethterm_s, SIOCGIFHWADDR, &ifr) == -1)
	{
		close(ethterm_s);
		ethterm_s = -1;
		return -1;
	}
	
	printf("index of eth0 is: %d\n", ethterm_sockaddr.sll_ifindex);
	printf("mac of eth0 is: %02x:%02x:%02x:%02x:%02x:%02x\n", \
	ifr.ifr_hwaddr.sa_data[0] & 0xff, \
	ifr.ifr_hwaddr.sa_data[1] & 0xff, \
	ifr.ifr_hwaddr.sa_data[2] & 0xff, \
	ifr.ifr_hwaddr.sa_data[3] & 0xff, \
	ifr.ifr_hwaddr.sa_data[4] & 0xff, \
	ifr.ifr_hwaddr.sa_data[5] & 0xff);
	
	memcpy(ethterm_sockaddr.sll_addr, ethterm_mac_dst, 6);

	// allocate memory for send and receive buffers
	ethterm_s_buf = qemu_mallocz(2048);
	ethterm_r_buf = qemu_mallocz(2048);
	if(ethterm_s_buf == NULL)
	{
		ethterm_cleanup();
		return 1;
	}
	
	// set the dest mac address
	memcpy(ethterm_s_buf, ethterm_mac_dst, 6);
	
	// set the src mac address
	memcpy(ethterm_s_buf + 6, ifr.ifr_hwaddr.sa_data, 6);
	
	// set the type
	*((uint16_t *) (ethterm_s_buf + 12)) = htons(ETHTERM_TYPE);
	
	return 0;
}

void ethterm_cleanup(void)
{
	if(ethterm_s_buf != NULL)
		qemu_free(ethterm_s_buf);
	if(ethterm_r_buf != NULL)
		qemu_free(ethterm_r_buf);
	if(ethterm_s != -1)
		close(ethterm_s);
	ethterm_s = -1;
	ethterm_s_buf = NULL;
	ethterm_r_buf = NULL;
}

static void sdl_update(DisplayState *ds, int x, int y, int w, int h)
{
	int i, j, l, p, ret;
	
    //printf("sdl_update(%d, %d, %d, %d)\n", x, y, w, h);
    //printf("guest_screen = %d, scaling_active = %d\n", (guest_screen) ? 1 : 0, scaling_active);
    //printf("ds (w h bpp ls) = (%d, %d, %d, %d)\n", ds_get_width(ds), ds_get_height(ds), ds_get_bits_per_pixel(ds), ds_get_linesize(ds));
    
    uint32_t * ds_data = (uint32_t *) ds_get_data(ds);
    int ds_ls = ds_get_linesize(ds);
    
    if((ds_get_bits_per_pixel(ds) == 32) && (ethterm_s != -1))
    {
		// send raw ethernet packets for updated region
		for(i = 0; (i < h) && ((y + i) < 720); i++)
		{
			//printf("sdl_update: ethterm send line %d: ", y + i);
			for(j = 0; (j < w) && ((x + j) < 1280); j += ETHTERM_PIXELS_PER_FRAME)
			{
				// calculate the number of pixels to send in the frame.
				// must be less than a certain maximum to fit in the
				// 1500 byte ethernet frame size limit
				p = ((w - j) > ETHTERM_PIXELS_PER_FRAME) ? ETHTERM_PIXELS_PER_FRAME : (w - j);
				if ((x + j + p) > 1280)
					p = 1280 - (x + j);
				
				//printf("%d->%d ", x + j, x + j + p);
				
				// set the data length (in number of 64 bit qwords)
				*((uint16_t *) (ethterm_s_buf + 14)) = htons(3 + (p / 2));
				
				// set the memory address
				*((uint32_t *) (ethterm_s_buf + 20)) = htonl((((y + i) * 2048) + (x + j)) * 4);
				
				// copy the pixel data from the display state struct to the send buffer
				memcpy(ethterm_s_buf + 24, (uint8_t *) ds_data + ((y + i) * ds_ls) + ((x + j) * 4), p * 4);
				
				// send the frame, making sure that at minimum 64 bytes are sent
				//printf("sending frame of length %d\n", 24 + (p * 4));
				l = (p >= 10) ? 24 + (p * 4) : 64;
				ret = sendto(ethterm_s, ethterm_s_buf, l, 0, (struct sockaddr *) &ethterm_sockaddr, sizeof(ethterm_sockaddr));
				if(ret == -1)
					printf("sdl_update: sendto returned -1, errno = %d\n", errno);
			}
			//printf("\n");
		}
	}
}

static void sdl_setdata(DisplayState *ds)
{
	printf("sdl_setdata()\n");
	
	/*ds_get_data(ds), ds_get_width(ds), ds_get_height(ds),
	ds_get_bits_per_pixel(ds), ds_get_linesize(ds),
	ds->surface->pf.rmask, ds->surface->pf.gmask,
	ds->surface->pf.bmask, ds->surface->pf.amask*/
}

static void sdl_resize(DisplayState *ds)
{
	printf("sdl_resize(%d, %d, %d)\n", ds_get_width(ds), ds_get_height(ds), ds_get_bits_per_pixel(ds));
}

static DisplaySurface* sdl_create_displaysurface(int width, int height)
{
	printf("sdl_create_displaysurface(%d, %d)\n", width, height);
	
    DisplaySurface *surface = (DisplaySurface*) qemu_mallocz(sizeof(DisplaySurface));
    if (surface == NULL) {
        fprintf(stderr, "sdl_create_displaysurface: malloc failed\n");
        exit(1);
    }

    surface->width = width;
    surface->height = height;
	
    surface->linesize = width * 4;
	surface->pf = qemu_default_pixelformat(32);

#ifdef HOST_WORDS_BIGENDIAN
	surface->flags = QEMU_ALLOCATED_FLAG | QEMU_BIG_ENDIAN_FLAG;
#else
	surface->flags = QEMU_ALLOCATED_FLAG;
#endif
    surface->data = (uint8_t*) qemu_mallocz(surface->linesize * surface->height);

    return surface;
}

static void sdl_free_displaysurface(DisplaySurface *surface)
{
	printf("sdl_free_displaysurface()\n");
    if (surface == NULL)
        return;
    
    if (surface->flags & QEMU_ALLOCATED_FLAG)
        qemu_free(surface->data);
    
    qemu_free(surface);
}

static DisplaySurface* sdl_resize_displaysurface(DisplaySurface *surface, int width, int height)
{
	printf("sdl_resize_displaysurface()\n");
    sdl_free_displaysurface(surface);
    return sdl_create_displaysurface(width, height);
}

static void sdl_refresh(DisplayState *ds)
{
    // check for ethernet frames
    int ret;
    uint32_t ethterm_keycode;
    uint8_t xt_keycode;
    ret = recvfrom(ethterm_s, ethterm_r_buf, 2048, MSG_DONTWAIT, NULL, NULL);
    if ((ret == -1) && (errno != EAGAIN))
    {
		printf("error: recvfrom returned -1, errno = %d\n", errno);
	}
	if (ret != -1)
	{
		ethterm_keycode = ntohl(*((uint32_t *) (ethterm_r_buf + 20)));
		xt_keycode = ps2toxt[ethterm_keycode & 0x7f];
		printf("sdl_refresh: received %x, converted to %x\n", ethterm_keycode, xt_keycode);
		if(xt_keycode == 0)
			printf("sdl_refresh: no conversion for ps2 keycode %x\n", ethterm_keycode);
		else
		{
		
			//if((ethterm_keycode & 0xff0000) == 0xe00000)
			//	kbd_put_keycode(0xe0);
			
			if((ethterm_keycode & 0xff00) == 0xf000)
				xt_keycode |= 0x80;
			
			kbd_put_keycode(xt_keycode);
		}
	}
	
    vga_hw_update();
}

static void sdl_fill(DisplayState *ds, int x, int y, int w, int h, uint32_t c)
{
    printf("sdl_fill()\n");
}

static void sdl_cleanup(void)
{
    printf("sdl cleanup\n");
    ethterm_cleanup();
}

static void sdl_mouse_warp(int x, int y, int on)
{
	printf("sdl_mouse_warp(%d, %d, %d)\n", x, y, on);
}

static void sdl_mouse_define(QEMUCursor *c)
{
	printf("sdl_mouse_define()\n");
}

void sdl_display_init(DisplayState *ds, int full_screen, int no_frame)
{
    DisplayAllocator *da;

	printf("sdl_display_init()\n");
	
    dcl = qemu_mallocz(sizeof(DisplayChangeListener));
    dcl->dpy_update = sdl_update;
    dcl->dpy_resize = sdl_resize;
    dcl->dpy_refresh = sdl_refresh;
    dcl->dpy_setdata = sdl_setdata;
    dcl->dpy_fill = sdl_fill;
    ds->mouse_set = sdl_mouse_warp;
    ds->cursor_define = sdl_mouse_define;
    register_displaychangelistener(ds, dcl);

    da = qemu_mallocz(sizeof(DisplayAllocator));
    da->create_displaysurface = sdl_create_displaysurface;
    da->resize_displaysurface = sdl_resize_displaysurface;
    da->free_displaysurface = sdl_free_displaysurface;
    if (register_displayallocator(ds, da) == da) {
        dpy_resize(ds);
    }

    atexit(sdl_cleanup);
    
    // initialize raw ethernet socket
    if(ethterm_init("eth0"))
    {
		printf("error: could not initialize ethterm on eth0\n");
	}
}
