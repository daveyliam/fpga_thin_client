/*
Sends a stream of raw frames to the FPGA thin client from stdin.

Client MAC address is hardcoded.
*/

#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_arp.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// packet structure
// 0  - 5  | mac_dst
// 6  - 11 | mac_src
// 12 - 13 | type
// 14 - 15 | data_length
// 16 - 19 | start_address
// 20 - 23 | 
// 24 - nn | data

#define ETHTERM_TYPE (0x88b5)

const char ethterm_mac_dst[] = "\x00\x50\x56\xab\xcd\xef";
static int ethterm_s = -1;
static struct sockaddr_ll ethterm_sockaddr;
char * ethterm_s_buf = NULL;

int ethterm_init(const char * if_name);
void ethterm_cleanup(void);

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

	// copy the given interface name to the ifr structure
	strncpy(ifr.ifr_name, if_name, IFNAMSIZ);
	
	// get the interface index
	if(ioctl(ethterm_s, SIOCGIFINDEX, &ifr) == -1)
	{
		ethterm_cleanup();
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
		ethterm_cleanup();
		return 1;
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

	// allocate memory for send buffer
	ethterm_s_buf = malloc(2048);
	
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
		free(ethterm_s_buf);
	if(ethterm_s != -1)
		close(ethterm_s);
	ethterm_s = -1;
	ethterm_s_buf = NULL;
}

void signal_handler(int signal)
{
	printf("\ncaught keyboard interrupt, exiting...\n");
	ethterm_cleanup();
	exit(1);
}

int main(int argc, char * argv[])
{
	signal(SIGINT, signal_handler);
	
	if(argc < 5) 
	{
		printf("usage: %s <interface> <width> <height> <bpp>\n",argv[0]);
		return 1;
	}
	
	if(ethterm_init(argv[1]))
	{
		printf("error: could not initialize raw sockets on %s\n", argv[1]);
		return 1;
	}
	
	int width = atoi(argv[2]);
	int height = atoi(argv[3]);
	int bpp = atoi(argv[4]);
	
	if((width <= 0) || (width > 1280))
	{
		printf("error: width must be between 0 and 1280 (got %d)\n", width);
		return 1;
	}
	
	if((height <= 0) || (height > 720))
	{
		printf("error: height must be between 0 and 720 (got %d)\n", height);
		return 1;
	}
	
	if((bpp != 16) && (bpp != 32))
	{
		printf("error: bpp must be either 16 or 32 (got %d)\n", bpp);
		return 1;
	}
	
	int bytes_per_pixel = bpp / 8;
	int pixels_per_frame = 1280 / bytes_per_pixel;
	
	int exit = 0;
	int fb_num = 1;
	
	int x, y, length;
	while(!exit)
	{
		fb_num = !fb_num;
		
		for(y = 0; (y < height) && (!exit); y++)
		{
			for(x = 0; x < width; x += pixels_per_frame)
			{

				if((width - x) < pixels_per_frame)
					length = width - x;
				else
					length = pixels_per_frame;

				*((uint16_t *) (ethterm_s_buf + 14)) = htons(3 + (length * bytes_per_pixel / 8));
				*((uint32_t *) (ethterm_s_buf + 16)) = htonl(0x00030000 | ((bpp == 16) << 1) | (fb_num));
				*((uint32_t *) (ethterm_s_buf + 20)) = htonl((!fb_num << 24) | ((y * 2048 * 4) + (x * bytes_per_pixel)));

				if(bytes_per_pixel != fread(ethterm_s_buf + 24, length, bytes_per_pixel, stdin))
				{
					printf("EOF reached\n");
					exit = 1;
					break;
				}
				
				if(sendto(ethterm_s, \
						ethterm_s_buf, \
						24 + (length * bytes_per_pixel), \
						0, \
						(struct sockaddr *) &ethterm_sockaddr, \
						sizeof(ethterm_sockaddr) \
					) == -1)
				{
					printf("sendto error, make sure interface is up\n");
					exit = 1;
					break;
				}
			}
		}
	}
	
	ethterm_cleanup();
	return 0;
}
