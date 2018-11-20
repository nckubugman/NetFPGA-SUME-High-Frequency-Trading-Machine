/*******************************************************************************
*
* Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
*                          Junior University
* All rights reserved.
*
* This software was developed by
* Stanford University and the University of Cambridge Computer Laboratory
* under National Science Foundation under Grant No. CNS-0855268,
* the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
* by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
* as part of the DARPA MRC research programme.
*
* @NETFPGA_LICENSE_HEADER_START@
*
* Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
* license agreements. See the NOTICE file distributed with this work for
* additional information regarding copyright ownership. NetFPGA licenses this
* file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
* "License"); you may not use this file except in compliance with the
* License. You may obtain a copy of the License at:
*
* http://www.netfpga-cic.org
*
* Unless required by applicable law or agreed to in writing, Work distributed
* under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied. See the License for the
* specific language governing permissions and limitations under the License.
*
* @NETFPGA_LICENSE_HEADER_END@
*
*
******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <net/if.h>
#include <time.h>
#include <inttypes.h>
#include "../common/reg_defines.h"
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include "../common/sume_util.h"
#include <pthread.h>



#define READ_CMD	0x11
#define WRITE_CMD	0x01
#define TABLE_SIZE      2048
#define COMMODITY_TABLE_SIZE      4096

static unsigned MAC_HI_REGS[] = {
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_0_HI,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_1_HI,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_2_HI,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_3_HI
};

static unsigned MAC_LO_REGS[] = {
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_0_LOW,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_1_LOW,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_2_LOW,
  SUME_OUTPUT_PORT_LOOKUP_0_MAC_3_LOW
};

char **hash_table_0;
char **hash_table_1;
char **hash_table_2;
char **hash_table_3;
int  hash_table_vld_0     [TABLE_SIZE/4] = {0};
int  hash_table_vld_1     [TABLE_SIZE/4] = {0};
int  hash_table_vld_2     [TABLE_SIZE/4] = {0};
int  hash_table_vld_3     [TABLE_SIZE/4] = {0};
char **hash_table2_0;
char **hash_table2_1;
char **hash_table2_2;
char **hash_table2_3;
int  hash_table2_vld_0     [4096/4] = {0};
int  hash_table2_vld_1     [4096/4] = {0};
int  hash_table2_vld_2     [4096/4] = {0};
int  hash_table2_vld_3     [4096/4] = {0};
int  write_index          [289]    = {0}; // stock code map to hash table index
int  write_index_2        [1550]    = {0}; // stock code map to hash table index
int  stock_order          [TABLE_SIZE]   = {0}; // hash table store original order of stock list
int  stock_order2          [4096]   = {0}; // hash table store original order of stock list
unsigned int stock_id_upper[289] = {0};
unsigned int stock_id_lower[289] = {0};
unsigned int commodity_index[289] = {0};
unsigned int commodity_id_upper[1550] = {0};
unsigned int commodity_id_lower[1550] = {0};
unsigned int extra[1550] = {0};
/*unsigned int input_stock_id_upper[1024] = {0};
unsigned int input_stock_id_lower[1024] = {0};
unsigned int input_commodity_index[1024] = {0};*/

/* Function declarations */
void prompt (void);
void help (void);
int  parse (char *);
void board (void);
void setip (void);
void setarp (void);
void setmac (void);
void listip (void);
void listarp (void);
void listmac (void);
void loadip (void);
void loadarp (void);
void loadmac (void);
void clearip (void);
void cleararp (void);
void showq(void);
uint8_t *parseip(char *str);
uint8_t * parsemac(char *str);


void listpkt(void);
void set_time(void);
void read_time(void);
void add_stock_id(unsigned int index, unsigned int upper, unsigned int lower, unsigned int commodity_addr);
//void add_stock_id(void);
void list_stock_id(void);
void add_commodity_index(unsigned int index, unsigned int commodity_index);
void list_commodity(void);
void add_order_index(unsigned int index, unsigned int upper, unsigned int lower);
void list_order(void);

void init_str_array();
void loadstrategy(void);
int  insert_cuckoo_hashing_four_divide(char *key, int order);
int  insert_cuckoo_hashing_four_divide_2(char *key, int order);
void load_commodity_index(void);
unsigned int one_at_a_time_0(char *key, int len);
unsigned int one_at_a_time_1(char *key, int len);
unsigned int one_at_a_time_2(char *key, int len);
unsigned int one_at_a_time_3(char *key, int len);

void stock_id_transfer(void);
unsigned int stock_id_msb24(char *temp);
unsigned int stock_id_lsb24(char *temp);
void commodity_id_transfer(void);

/*----------- TCP/FIX Connection ------- */


void listflag(void);
void setflag(void);
void clearflag(void);
void set_connection(void);
void list_shutdown_flag(void);
void set_shutdown_flag(void);
void clear_shutdown_flag(void);
void shutdown_connect(void);

void Connect_log_trig(void);

void read_resend_seq(void);

void set_seq(void);


/* Global vars */
int sume;

void init_str_array(){
	int i = 0;
	hash_table_0 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_1 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_2 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_3 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table2_0 = (char **)malloc((4096/4) * sizeof(char *));
	hash_table2_1 = (char **)malloc((4096/4) * sizeof(char *));
	hash_table2_2 = (char **)malloc((4096/4) * sizeof(char *));
	hash_table2_3 = (char **)malloc((4096/4) * sizeof(char *));
	for(i=0; i<TABLE_SIZE/4; i++){
		hash_table_0[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_1[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_2[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_3[i] = (char *)malloc(sizeof(char) * 7);
	}
	for(i=0; i<4096/4; i++){
		hash_table2_0[i] = (char *)malloc(sizeof(char) * 7);
		hash_table2_1[i] = (char *)malloc(sizeof(char) * 7);
		hash_table2_2[i] = (char *)malloc(sizeof(char) * 7);
		hash_table2_3[i] = (char *)malloc(sizeof(char) * 7);
	}
}	
void loadstrategy(void){
	int i = 0, j = 0, k = 0;
	int count = 0;
	char line[100];
    char *temp = NULL, *num = NULL;
	char price[10], qty[10];
	int   digit;
    //FILE *rd_ptr = fopen("./stock_strategy_load_1118.txt", "r"); 
    //FILE *rd_ptr = fopen("./stock_data/input_data.txt", "r"); 
    FILE *rd_ptr = fopen("./stock_data/Stock_ID.txt", "r"); 
    
    // generate hash index first
    while(fgets(line, 100, rd_ptr)){
        temp = strtok(line, "\t");
            if(insert_cuckoo_hashing_four_divide(temp, j) == -1){
		count++;
		/*printf("%s\n", temp);
                printf("Collision occurs at [%d] stock code\n", j);
		printf("hash rate : %f\n", (float)(j-count)/j);
		printf("collision : %d\n", count);*/
                //return;
            }
            j++;
        //}
    }
    rewind(rd_ptr);
    j = 0;
    count = 0;
    for(j=0; j<289; j++){
	add_stock_id(write_index[j], stock_id_upper[j], stock_id_lower[j], commodity_index[j]);
	//add_stock_id(36, stock_id_upper[j], stock_id_lower[j], commodity_index[j]);
	printf("%s %d %u %u %u\n", hash_table_0[write_index[j]], write_index[j], stock_id_upper[j], stock_id_lower[j], commodity_index[j]);
    }

/*
    for(j=0; j<512; j++){
	if(hash_table_vld_0[j] == 1){
		//printf("1\n");
		printf("%d: %s\n", j, hash_table_0[j]);
		count++;
	}
	else{
		printf("%d: NULL\n", j);
		//printf("0\n");
	}
    }

    printf("%d\n", count);*/
}

void load_commodity_index(void){
	int i = 0, j = 0, k = 0;
	int count = 0;
	char line[100];
    char *temp = NULL, *num = NULL;
	char price[10], qty[10];
	int   digit;
    FILE *rd_ptr = fopen("./stock_data/Commodity.txt", "r"); 
    
    // generate hash index first
    while(fgets(line, 100, rd_ptr)){
        temp = strtok(line, "\t");
            if(insert_cuckoo_hashing_four_divide_2(temp, j) == -1){
		count++;
		/*printf("%s\n", temp);
                printf("Collision occurs at [%d] stock code\n", j);
		printf("hash rate : %f\n", (float)(j-count)/j);
		printf("collision : %d\n", count);*/
                //return;
            }
            j++;
        //}
    }
    rewind(rd_ptr);
    j = 0;
    count = 0;
    for(j=0; j<1550; j++){
	add_commodity_index(j, write_index_2[j]);
	add_order_index(write_index_2[j], commodity_id_upper[j], commodity_id_lower[j]);
	printf("%d %d\n", j, write_index_2[j]);
    }

}

int insert_cuckoo_hashing_four_divide(char *key, int order){
    int  i, j;

    // insert hash function
    unsigned int index0 = one_at_a_time_0(key, 6) % (TABLE_SIZE/4);
    unsigned int index1 = one_at_a_time_1(key, 6) % (TABLE_SIZE/4);
//    unsigned int index2 = one_at_a_time_2(key, 6) % (TABLE_SIZE/4);
//    unsigned int index3 = one_at_a_time_3(key, 6) % (TABLE_SIZE/4);
    int N = 1024, k = 0, run = i, temp;
    unsigned int upper_temp, lower_temp, commodity_index_temp;
    char temp_key[7];

    while(k<N){
        if(hash_table_vld_0[index0] == 0){
            strncpy(hash_table_0[index0], key, 6);
            stock_order[index0]            = order;
            write_index[order]             = index0;
            hash_table_vld_0[index0]       = 1;
            return 1;
        }
        else if(hash_table_vld_1[index1] == 0){
            strncpy(hash_table_1[index1], key, 6);
            stock_order[(TABLE_SIZE/4)+index1]   = order;
            write_index[order]                   = (TABLE_SIZE/4)+index1;
            hash_table_vld_1[index1]             = 1;
            return 1;
        }
        /*else if(hash_table_vld_2[index2] == 0){
            strncpy(hash_table_2[index2], key, 6);
            stock_order[(TABLE_SIZE/4)*2+index2] = order;
            write_index[order]                   = (TABLE_SIZE/4)*2+index2;
            hash_table_vld_2[index2]             = 1;
            return 1;
        }
        else if(hash_table_vld_3[index3] == 0){
            strncpy(hash_table_3[index3], key, 6);
            stock_order[(TABLE_SIZE/4)*3+index3] = order;
            write_index[order]                   = (TABLE_SIZE/4)*3+index3;
            hash_table_vld_3[index3]             = 1;
            return 1;
        }*/
        else{
            strncpy(temp_key, key, 6);
            strncpy(key, hash_table_0[index0], 6);
            strncpy(hash_table_0[index0], temp_key, 6);
            write_index[order] = index0;
            temp = stock_order[index0];
            stock_order[index0] = order;
            order = temp;
            index0 = one_at_a_time_0(key, 6) % (TABLE_SIZE/4);
            index1 = one_at_a_time_1(key, 6) % (TABLE_SIZE/4);
            //index2 = one_at_a_time_2(key, 6) % (TABLE_SIZE/4);
            //index3 = one_at_a_time_3(key, 6) % (TABLE_SIZE/4);
        }
        k++;
    }
    return -1;
}

int insert_cuckoo_hashing_four_divide_2(char *key, int order){
    int  i, j;

    // insert hash function
    unsigned int index0 = one_at_a_time_0(key, 6) % (4096/4);
    unsigned int index1 = one_at_a_time_1(key, 6) % (4096/4);
    unsigned int index2 = one_at_a_time_2(key, 6) % (4096/4);
    unsigned int index3 = one_at_a_time_3(key, 6) % (4096/4);
    int N = 1024, k = 0, run = i, temp;
    unsigned int upper_temp, lower_temp, commodity_index_temp;
    char temp_key[7];

    while(k<N){
        if(hash_table2_vld_0[index0] == 0){
            strncpy(hash_table2_0[index0], key, 6);
            stock_order2[index0]            = order;
            write_index_2[order]             = index0;
            hash_table2_vld_0[index0]       = 1;
            return 1;
        }
        else if(hash_table2_vld_1[index1] == 0){
            strncpy(hash_table2_1[index1], key, 6);
            stock_order2[(TABLE_SIZE/4)+index1]   = order;
            write_index_2[order]                   = (4096/4)+index1;
            hash_table2_vld_1[index1]             = 1;
            return 1;
        }
        else if(hash_table2_vld_2[index2] == 0){
            strncpy(hash_table2_2[index2], key, 6);
            stock_order2[(TABLE_SIZE/4)*2+index2] = order;
            write_index_2[order]                   = (4096/4)*2+index2;
            hash_table2_vld_2[index2]             = 1;
            return 1;
        }
        else if(hash_table2_vld_3[index3] == 0){
            strncpy(hash_table2_3[index3], key, 6);
            stock_order2[(TABLE_SIZE/4)*3+index3] = order;
            write_index_2[order]                   = (4096/4)*3+index3;
            hash_table2_vld_3[index3]             = 1;
            return 1;
        }
        else{
            strncpy(temp_key, key, 6);
            strncpy(key, hash_table2_0[index0], 6);
            strncpy(hash_table2_0[index0], temp_key, 6);
            write_index_2[order] = index0;
            temp = stock_order2[index0];
            stock_order2[index0] = order;
            order = temp;
            index0 = one_at_a_time_0(key, 6) % (4096/4);
            index1 = one_at_a_time_1(key, 6) % (4096/4);
            index2 = one_at_a_time_2(key, 6) % (4096/4);
            index3 = one_at_a_time_3(key, 6) % (4096/4);
        }
        k++;
    }
    return -1;
}


unsigned int one_at_a_time_0(char *key, int len)
{
  unsigned int hash;
  int   i;
  for (hash=0, i=0; i<len; i++)
  {
    hash += key[i];
    hash += (hash << 10);
    hash ^= (hash >> 6);
  }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
  return hash;
}

unsigned int one_at_a_time_1(char *key, int len)
{
  unsigned int hash;
  int   i;
  for (hash=0, i=0; i<len; i++)
  {
    hash += key[i];
    hash += (hash << 9);
    hash ^= (hash >> 4);
  }
    hash += (hash << 5);
    hash ^= (hash >> 9);
    hash += (hash << 13);
  return hash;
}

unsigned int one_at_a_time_2(char *key, int len)
{
  unsigned int hash;
  int   i;
  for (hash=0, i=0; i<len; i++)
  {
    hash += key[i];
    hash += (hash << 11);
    hash ^= (hash >> 5);
  }
    hash += (hash << 4);
    hash ^= (hash >> 10);
    hash += (hash << 14);
  return hash;
}

unsigned int one_at_a_time_3(char *key, int len)
{
  unsigned int hash;
  int   i;
  for (hash=0, i=0; i<len; i++)
  {
    hash += key[i];
    hash += (hash << 12);
    hash ^= (hash >> 3);
  }
    hash += (hash << 6);
    hash ^= (hash >> 12);
    hash += (hash << 12);
  return hash;
}

unsigned int stock_id_msb24(char *temp){
	unsigned int stock_val = 0;
	stock_val += temp[0];
	stock_val <<= 8;
	stock_val += temp[1];
	stock_val <<= 8;
	stock_val += temp[2];
	return stock_val;
}

unsigned int stock_id_lsb24(char *temp){
	unsigned int stock_val = 0;
	stock_val += temp[3];
	stock_val <<= 8;
	stock_val += temp[4];
	stock_val <<= 8;
	stock_val += temp[5];
	return stock_val;
}

void stock_id_transfer(){
	char line[100];
	char prev[10] = "0";
	char *temp = NULL, *temp2 = NULL;
	int  max = 0, count = 0, m = -1, i = 0;
	unsigned long long endpoint = 0;
	unsigned long long addr = 0;
	int  count_table[289] = {};
        int  count_distributed[50] = {};
	FILE *rd_ptr = fopen("./stock_data/kgi_commodity_fix.txt", "r");
        temp = malloc(sizeof(char) * 11);	
	

	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			if(count > max)
				max = count;
			if(m != -1){ // count # of warrants in a stock_ID
				count_table[m] = count;
				count_distributed[count]++;
			}
			m++;
			count = 1;
		}
		else{
			count++;
		}
		int n = strlen(temp) + 1;
		strncpy(prev, temp, n);
	}
	count_table[m] = count;
	rewind(rd_ptr);
	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			addr = endpoint<<11; 
			addr = addr + endpoint + count_table[i] - 1;
			stock_id_upper[i] = stock_id_msb24(temp); // cut Stock_ID into MSB_24 & LSB_24
			stock_id_lower[i] = stock_id_lsb24(temp);
			commodity_index[i] = addr;
			endpoint += count_table[i];
			i++;
		}
		int n = strlen(temp) + 1;
		strncpy(prev, temp, n);

	}
	fclose(rd_ptr);

	
	return 0;


}

void commodity_id_transfer(){
	char line[100];
	char prev[10] = "0";
	char *temp = NULL, *temp2 = NULL;
	int  max = 0, count = 0, m = -1, i = 0;
	unsigned long long endpoint = 0;
	unsigned long long addr = 0;
	int  count_table[289] = {};
        int  count_distributed[50] = {};
	FILE *rd_ptr = fopen("./stock_data/Commodity.txt", "r");
        //FILE *rd_ptr = fopen("./Stock_ID.txt", "r");
        temp = malloc(sizeof(char) * 11);	
	

	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			commodity_id_upper[i] = stock_id_msb24(temp);
			commodity_id_lower[i] = stock_id_lsb24(temp);
			//extra[i] = 3;
			//printf("%u\t%u\t%llu\n", commodity_id_upper[i], commodity_id_lower[i], extra[i]);
			i++;
		}
		int n = strlen(temp) + 1;
		strncpy(prev, temp, n);

	}
	fclose(rd_ptr);
	/*for(i = 0; i < 289; i++)
		printf("Stock_ID %d : %d\n", i+1, count_table[i]);
	for(i=0; i<50; i++)
		printf("%d\n", count_distributed[i]);
	printf("Max # of Commodity = %d\n", max);*/
        //fclose(wr_ptr0);

	
	return 0;


}

void  Connect_log_trig(void){
    int i= 0;
    int j= 0;
    int keep_fix_logout_val=0;
    int keep_fix_logon_val=0;
    int keep_tcp_logout_val=0;
    int keep_tcp_logon_val=0;
    int read_fix_logout;
    int read_fix_logon;
    int read_tcp_logout;
    int read_tcp_logon;
    unsigned  int value ,tcp_value;
    unsigned  int fix_logout_val ,fix_logon_val,tcp_logon_val,tcp_logout_val;
    read_fix_logon  = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_LOGON_TRIGGER_0 ,&fix_logon_val);
    read_fix_logout = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_LOGOUT_TRIGGER_0,&fix_logout_val);
    read_tcp_logout = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_TCP_LOGOUT_HANDSHAKE_TRIGGER_0,&tcp_logout_val);
    read_tcp_logon  = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_TCP_LOGON_HANDSHAKE_TRIGGER_0,&tcp_logon_val);
    
    keep_fix_logout_val = fix_logout_val;
    keep_fix_logout_val++;
    keep_fix_logon_val  = fix_logon_val;
    keep_fix_logon_val++;
    keep_tcp_logout_val = tcp_logout_val;
    keep_tcp_logout_val++;
    keep_tcp_logon_val =  tcp_logon_val;
    keep_tcp_logon_val++;

    
    while (1) {
     
     sleep(1);    
     read_fix_logon  = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_LOGON_TRIGGER_0, &fix_logon_val);
     read_fix_logout = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_LOGOUT_TRIGGER_0,&fix_logout_val);
     read_tcp_logon  = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_TCP_LOGON_HANDSHAKE_TRIGGER_0,&tcp_logon_val);
     read_tcp_logout = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_TCP_LOGOUT_HANDSHAKE_TRIGGER_0,&tcp_logout_val);
     if(fix_logon_val==keep_fix_logon_val)
     {
             if(tcp_logon_val==keep_tcp_logon_val){
                        ++keep_tcp_logon_val;
                        printf("\nTCP Connect handshake Detect!\n");
             }else{
             //           printf("TCP Connect handshake No Detect,Now Trigger is %d,Lock value is %d *****\n",tcp_logon_val,keep_tcp_logon_val);
             }
             ++keep_fix_logon_val;
             printf("\nFIX LOGON Detect !\n");
             sleep(5);

     }
     else{
        if(tcp_logon_val==keep_tcp_logon_val){
               ++keep_tcp_logon_val;
               printf("\nTCP Connect handshake Detect!\n");
        }else{
              //   printf("TCP Connect handshake No Detect,Now Trigger is %d,Lock value is %d *****\n",tcp_logon_val,keep_tcp_logon_val);
        }
/*
        printf("******FIX LOGON NO Detect (For Debug),Now Logon Trigger is %d, Lock value is %d******\n",fix_logon_val,keep_fix_logon_val);
        sleep(5);
*/
     }
     if(fix_logout_val==keep_fix_logout_val)
     {
	     if(tcp_logout_val==keep_tcp_logout_val){
			++keep_tcp_logout_val;
			printf("\nTCP Dis_connect handshake Detect!\n");
	     }else{
		//	printf("TCP Dis_connect handshake No Detect,Now Trigger is %d,Lock value is %d *****\n",tcp_logout_val,keep_tcp_logout_val);
	     }
	     ++keep_fix_logout_val;
             printf("\nFIX LOGOUT Detect !\n");
	     //sleep(5);
	     
     }
     else{
	if(tcp_logout_val==keep_tcp_logout_val){
	       ++keep_tcp_logout_val;	
               printf("\nTCP Dis_connect handshake Detect!\n");
        }else{
		//printf("TCP Dis_connect handshake No Detect,Now Trigger is %d,Lock value is %d *****\n",tcp_logout_val,keep_tcp_logout_val);
        }
/*	
	printf("******FIX LOGOUT NO Detect (For Debug),Now Logout Trigger is %d, Lock value is %d******\n",fix_logout_val,keep_fix_logout_val);
	sleep(5);
*/	
     }
   }
}


void  fix_resend_trig(void){
    int i= 1;
    int j= 0;
    int err;
    unsigned  int value ;
    err = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_RESEND_TRIGGER_0,&value);
    j = value;
    j++ ;

    while (1) {

     sleep(1);
     err = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_RESEND_TRIGGER_0,&value);
     //err = writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0,1);
     //printf("value:%d \n",value);
     if(value==j)
     {
             //++i;
             ++j;
             printf("FIX RESEND Detect !\n");
             sleep(5);

             //break;
             //exit(1);
             //pthread_exit(0);
     }
     else{
	/*
        printf("******FIX RESEND NO Detect (For Debug),Now RESEND Trigger is %d, Lock value is %d******\n",value,j);
        sleep(5);
	*/
        //break;
        //pthread_exit(0);
     }
   }
}



int main(int argc, char *argv[])
{
  init_str_array();
  stock_id_transfer();
  commodity_id_transfer();
  //loadstrategy();
  sume = socket(AF_INET6, SOCK_DGRAM, 0);
  if (sume == -1) {
  	sume = socket(AF_INET, SOCK_DGRAM, 0);
        if (sume == -1){
		printf("ERROR socket failed for AF_INET6 and AF_INET");
		return 0;
	}
   }
                    
    int i = 1;
    int err;
    unsigned  int value ;
    void*  result;
    pthread_t check_logout;
    pthread_t check_resend;
    pthread_t command;
   // while(1){
      pthread_create(&check_logout,NULL,(void*)Connect_log_trig,NULL);
      pthread_create(&command,NULL,(void*)prompt,NULL);
      pthread_create(&check_resend,NULL,(void*)fix_resend_trig,NULL);
      pthread_join(check_logout,NULL);
      pthread_join(command,NULL);  
      pthread_join(check_resend,NULL);
   // }
    //prompt();

  return 0;
}

void prompt(void) {

    int i = 1;
    int err;
    unsigned  int value ;
    void*  result;
    pthread_t check;

    //pthread_create(&check,NULL,(void*)fix_logout_trig,NULL);
    

     
    while (1) {
    printf("> ");
    char c[10];
    scanf("%s", c);
    int res = parse(c);
    switch (res) {
    case 0:
      listip();
      break;
    case 1:
      listarp();
      break;
    case 2:
      setip();
      break;
    case 3:
      setarp();
      break;
    case 4:
      loadip();
      break;
    case 5:
      loadarp();
      break;
    case 6:
      clearip();
      break;
    case 7:
      cleararp();
      break;
    case 12:
      listmac();
      break;
    case 13:
      setmac();
      break;
    case 14:
      loadmac();
      break;
    case 8:
      help();
      break;
    case 9:
      listpkt();
      break;
    case 10:
      set_time();
      break;
    case 11:
      read_time();
      break;
    case 16:
      loadstrategy();
      break;
    case 17:
      list_stock_id();
      break;
    case 18:
      load_commodity_index();
      break;
    case 19:
      list_commodity();
      break;
    case 20:
      list_order();
      break;
    case 21:
      set_connection();
      break;
    case 22:
      shutdown_connect();
      break;
    case 23:
      read_resend_seq();
      break;
    case 24:
      set_seq();
      break;
    case 15:
      return;
    default:
      printf("Unknown command, type 'help' for list of commands\n");
    }
    //pthread_exit(0);
    //break;
/*
    err = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_FIX_LOGOUT_TRIGGER_0,&value);
    printf("value:%d \n",value);
    if(value)
    {
       printf("FIX LOGOUT Detect !\n");
       exit(1);
    }
*/
  }
}

void help(void) {
  printf("Commands:\n");
  printf("  listip        - Lists entries in IP routing table\n");
  printf("  listarp       - Lists entries in the ARP table\n");
  printf("  listmac       - Lists the MAC addresses of the router ports\n");
  printf("  setip         - Set an entry in the IP routing table\n");
  printf("  setarp        - Set an entry in the ARP table\n");
  printf("  setmac        - Set the MAC address of a router port\n");
  printf("  loadip        - Load IP routing table entries from a file\n");
  printf("  loadarp       - Load ARP table entries from a file\n");
  printf("  loadmac       - Load MAC addresses of router ports from a file\n");
  printf("  clearip       - Clear an IP routing table entry\n");
  printf("  cleararp      - Clear an ARP table entry\n");
  printf("  settime       - Set time\n");
  printf("  loadstocktable     - Add stock ID data into SUME\n");
  printf("  liststocktable     - Show the stock table current statistic\n");
  printf("  loadwarrants       - Add warrants ID data and Order table data into SUME\n");
  printf("  listwarrantstable  - Show the warrants table current statistic\n");
  printf("  listordertable     - Show the order table current statistic\n");
  printf("  setstrategy   - Set strategy entry\n");
  printf("  setcon        - set connection\n");
  printf("  shutdown      - shutdown connection\n");
  printf("  showresend  -  read FIX Resend sequence number \n");
  printf("  setseq        - set FIX Seqence number \n");
  printf("  help          - Displays this list\n");
  printf("  quit          - Exit this program\n");
}


void addmac(int port, uint8_t *mac) {
  int err;

  err=writeReg(sume,MAC_HI_REGS[port], mac[0] << 8 | mac[1]);
  if(err) printf("0x%08x: ERROR\n", MAC_HI_REGS[port]);
  err=writeReg(sume,MAC_LO_REGS[port], mac[2] << 24 | mac[3] << 16 | mac[4] << 8 | mac[5]);
  if(err) printf("0x%08x: ERROR\n", MAC_LO_REGS[port]);
}

void addarp(int entry, uint8_t *ip, uint8_t *mac) {
  int err;

  uint32_t table_address;
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_ARP_CAM_ADDRESS;
  table_address = table_address | entry;

  uint32_t cmd;
  cmd = (uint32_t)WRITE_CMD;

  // |-- 						INDIRECTWRDATA 128bit						      --|
  // |- -INDIRECTWRDATA_A_HI 32bit- -INDIRECTWRDATA_A_LOW 32bit- -INDIRECTWRDATA_B_HI 32bit- -INDIRECTWRDATA_B_LOW 32bit-      -|
  // |-- 		mac_hi 		-- 		mac_lo 	      -- 	0x0000 		   -- 		IP 	      --|
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, ip[0] << 24 | ip[1] << 16 | ip[2] << 8 | ip[3]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI,  mac[0] << 8 | mac[1]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, mac[2] << 24 | mac[3] << 16 | mac[4] << 8 | mac[5]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);

  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

}

void addip(int entry, uint8_t *subnet, uint8_t *mask, uint8_t *nexthop, int port) {
  int err;
  uint32_t table_address;

  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_LPM_TCAM_ADDRESS;
  table_address = table_address | entry;

  // |-- 						INDIRECTWRDATA 128bit							--|
  // |- -INDIRECTWRDATA_A_HI 32bit- -INDIRECTWRDATA_A_LOW 32bit- -INDIRECTWRDATA_B_HI 32bit- -INDIRECTWRDATA_B_LOW 32bit-	 -|
  // |-- 		IP 		-- 	next_IP 	     -- 	mask 		 -- 	next_port 	      	--|
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, subnet[0] << 24 | subnet[1] << 16 | subnet[2] << 8 | subnet[3]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, mask[0] << 24 | mask[1] << 16 | mask[2] << 8 | mask[3]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, nexthop[0] << 24 | nexthop[1] << 16 | nexthop[2] << 8 | nexthop[3]);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, port);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW);

  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, WRITE_CMD);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}

void setip(void) {
  printf("Enter [entry] [subnet]      [mask]       [nexthop] [port]:\n");
  printf("e.g.     0   192.168.1.0  255.255.255.0  15.1.3.1     4:\n");
  printf(">> ");

  char subnet[15], mask[15], nexthop[15];
  int port, entry;
  scanf("%i %s %s %s %x", &entry, subnet, mask, nexthop, &port);

  if ((entry < 0) || (entry > (SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_LPM_TCAM_DEPTH-1))) {
    printf("Entry must be between 0 and 31. Aborting\n");
    return;
  }

  if ((port < 1) || (port > 255)) {
    printf("Port must be between 1 and ff.  Aborting\n");
    return;
  }

  uint8_t *sn = parseip(subnet);
  uint8_t *m = parseip(mask);
  uint8_t *nh = parseip(nexthop);

  addip(entry, sn, m, nh, port);
}

void setarp(void) {
  printf("Enter [entry] [ip] [mac]:\n");
  printf(">> ");

  char nexthop[15], mac[30];
  int entry;
  scanf("%i %s %s", &entry, nexthop, mac);

  if ((entry < 0) || (entry > (SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_ARP_CAM_DEPTH-1))) {
    printf("Entry must be between 0 and 31. Aborting\n");
    return;
  }

  uint8_t *nh = parseip(nexthop);
  uint8_t *m = parsemac(mac);

  addarp(entry, nh, m);
}

void setmac(void) {
  printf("Enter [port] [mac]:\n");
  printf(">> ");

  char mac[30];
  int port;
  scanf("%i %s", &port, mac);

  if ((port < 0) || (port > 3)) {
    printf("Port must be between 0 and 3. Aborting\n");
    return;
  }

  uint8_t *m = parsemac(mac);

  addmac(port, m);
}

void listip(void) {
  int i;
  int err;
  uint32_t table_address;
  for (i = 0; i < SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_LPM_TCAM_DEPTH; i++) {
    unsigned subnet, mask, nh, valport;
    table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_LPM_TCAM_ADDRESS;
    table_address = table_address | i;

    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, READ_CMD);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &subnet);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI, &mask);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &nh);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &valport);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    
    printf("Entry #%i:   ", i);
    int port = valport & 0xff;
    if (subnet!=0 || mask!=0xffffffff || port!=0) {
      printf("Subnet: %i.%i.%i.%i, ", subnet >> 24, (subnet >> 16) & 0xff, (subnet >> 8) & 0xff, subnet & 0xff);
      printf("Mask: 0x%x, ", mask);
      printf("Next Hop: %i.%i.%i.%i, ", nh >> 24, (nh >> 16) & 0xff, (nh >> 8) & 0xff, nh & 0xff);
      printf("Port: 0x%02x\n", port);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void listarp(void) {
  int i = 0;
  int err;
  uint32_t table_address;
  uint32_t cmd;
  for (i = 0; i < SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_ARP_CAM_DEPTH; i++) {
    unsigned ip, machi, maclo;

    table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_ARP_CAM_ADDRESS;
    table_address = table_address | i;
    cmd = (uint32_t)READ_CMD;

    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &ip);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &machi);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &maclo);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);

    printf("Entry #%i:   ", i);
    if (ip!=0) {
      printf("IP: %i.%i.%i.%i, ", ip >> 24, (ip >> 16) & 0xff, (ip >> 8) & 0xff, ip & 0xff);
      printf("MAC: %x:%x:%x:%x:%x:%x\n", (machi >> 8) & 0xff, machi & 0xff,
              (maclo >> 24) & 0xff, (maclo >> 16) & 0xff,
              (maclo >> 8) & 0xff, (maclo) & 0xff);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void listmac(void) {
  int i = 0;
  int err;
  for (i = 0; i < 4; i++) {
    unsigned machi, maclo;

    err=readReg(sume,MAC_HI_REGS[i], &machi);
    if(err) printf("0x%08x: ERROR\n", MAC_HI_REGS[i]);
    err=readReg(sume,MAC_LO_REGS[i], &maclo);
    if(err) printf("0x%08x: ERROR\n", MAC_LO_REGS[i]);

    printf("Port #%i:   ", i);
    printf("MAC: %x:%x:%x:%x:%x:%x\n", (machi >> 8) & 0xff, machi & 0xff,
              (maclo >> 24) & 0xff, (maclo >> 16) & 0xff,
              (maclo >> 8) & 0xff, (maclo) & 0xff);
  }
}

void loadip(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp;
  char subnet[20], mask[20], nexthop[20];
  int entry, port;
  if((fp = fopen(fn, "r")) ==NULL) {
    printf("Error: cannot open file %s.\n", fn);
    return;
  }
  while (fscanf(fp, "%i %s %s %s %x", &entry, subnet, mask, nexthop, &port) != EOF) {
    uint8_t *sn = parseip(subnet);
    uint8_t *m = parseip(mask);
    uint8_t *nh = parseip(nexthop);

    addip(entry, sn, m, nh, port);
  }
}

void loadarp(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp = fopen(fn, "r");
  char ip[20], mac[20];
  int entry;
  while (fscanf(fp, "%i %s %s", &entry, ip, mac) != EOF) {
    uint8_t *i = parseip(ip);
    uint8_t *m = parsemac(mac);

    addarp(entry, i, m);
  }
}

void loadmac(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp = fopen(fn, "r");
  char mac[20];
  int port;
  while (fscanf(fp, "%i %s", &port, mac) != EOF) {
    uint8_t *m = parsemac(mac);

    addmac(port, m);
  }
}

void clearip(void) {
  int entry;
  int err;
  printf("Specify entry:\n");
  printf(">> ");
  scanf("%i", &entry);


  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, 0xffffffff);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW);

  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_LPM_TCAM_ADDRESS | entry);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, 1);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}

void cleararp(void) {
  int entry;
  int err;
  printf("Specify entry:\n");
  printf(">> ");
  scanf("%i", &entry);

  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI,  0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);

  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, SUME_OUTPUT_PORT_LOOKUP_0_MEM_IP_ARP_CAM_ADDRESS | entry);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, 1);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}


int parse(char *word) {
  if (!strcmp(word, "listip"))
    return 0;
  if (!strcmp(word, "listarp"))
    return 1;
  if (!strcmp(word, "setip"))
    return 2;
  if (!strcmp(word, "setarp"))
    return 3;
  if (!strcmp(word, "loadip"))
    return 4;
  if (!strcmp(word, "loadarp"))
    return 5;
  if (!strcmp(word, "clearip"))
    return 6;
  if (!strcmp(word, "cleararp"))
    return 7;
  if (!strcmp(word, "listmac"))
    return 12;
  if (!strcmp(word, "setmac"))
    return 13;
  if (!strcmp(word, "loadmac"))
    return 14;
  if (!strcmp(word, "help"))
    return 8;
  if (!strcmp(word, "listpkt"))
    return 9;
  if (!strcmp(word, "settime"))
    return 10;
  if (!strcmp(word, "readtime"))
    return 11;
  if (!strcmp(word, "loadstocktable"))
    return 16;
  if (!strcmp(word, "liststocktable"))
    return 17;
  if (!strcmp(word, "loadwarrants"))
    return 18;
  if (!strcmp(word, "listwarrantstable"))
    return 19;
  if (!strcmp(word, "listordertable"))
    return 20;
  if (!strcmp(word, "setcon"))
    return 21;
  if (!strcmp(word, "shutdown"))
    return 22;
  if (!strcmp(word, "showresend"))
    return 23;
  if (!strcmp(word, "setseq"))
    return 24;

  if (!strcmp(word, "quit"))
    return 15;
  return -1;
}

uint8_t * parseip(char *str) {
  uint8_t *ret = (uint8_t *)malloc(4 * sizeof(uint8_t));
  char *num = (char *)strtok(str, ".");
  int index = 0;
  while (num != NULL) {
    ret[index++] = atoi(num);
    num = (char *)strtok(NULL, ".");
  }
  return ret;
}


uint8_t * parsemac(char *str) {
        uint8_t *ret = (uint8_t *)malloc(6 * sizeof(char));
        char *num = (char *)strtok(str, ":");
        int index = 0;
        while (num != NULL) {
                int i;
                sscanf(num, "%x", &i);
                ret[index++] = i;
                num = (char *)strtok(NULL, ":");
        }
        return ret;
}
void listpkt(void) {
//  int i;
  int err;
  //uint32_t table_address;
  uint32_t pkt_send_from_cpu = 0;
  err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_PKT_SENT_FROM_CPU_CNTR, &pkt_send_from_cpu);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_PKT_SENT_FROM_CPU_CNTR);
  printf("pkt_sent_from_cpu: %d\n", pkt_send_from_cpu);
  err=readReg(sume,SUME_INPUT_ARBITER_0_PKTIN, &pkt_send_from_cpu);
  if(err) printf("0x%08x: ERROR\n", SUME_INPUT_ARBITER_0_PKTIN);
  printf("input arbiter pkt in: %d\n", pkt_send_from_cpu);
  err=readReg(sume,SUME_INPUT_ARBITER_0_PKTOUT, &pkt_send_from_cpu);
  if(err) printf("0x%08x: ERROR\n", SUME_INPUT_ARBITER_0_PKTOUT);
  printf("input arbiter pkt out: %d\n", pkt_send_from_cpu);
  err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0, &pkt_send_from_cpu);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0);
  printf("connect_signal: %d\n", pkt_send_from_cpu);
}

void set_time(){
        int err;
        time_t rawtime;
        struct timespec spec;
        struct tm *info;
        long ms;
        clock_gettime(CLOCK_REALTIME, &spec);

        rawtime = spec.tv_sec;
        ms = round(spec.tv_nsec / 1.0e6);
        info = localtime( &rawtime );
        printf("Current local time and date: %s", asctime(info));
        printf("%d %d %d %d %d %d \n", info->tm_year+1900, info->tm_mon+1, info->tm_mday, info->tm_hour-8, info->tm_min+1, info->tm_sec+1);
        //writeReg(&nf2, ROUTER_OP_LUT_KERNEL_TIME_TABLE_ENTRY_MS_REG, ms);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MS_0, ms);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MS_0);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_S_0, info->tm_sec+1);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_S_0);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MIN_0, info->tm_min+1);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MIN_0);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_HOUR_0, info->tm_hour-8);
//        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_HOUR_0, info->tm_hour+16);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_HOUR_0);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_DAY_0, info->tm_mday);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_DAY_0);
        err=writeReg(sume, SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MONTH_0, info->tm_mon+1);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MONTH_0);
        err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_YEAR_0, info->tm_year+1900);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_YEAR_0);
}
void read_time(){
        int err;
        time_t rawtime;
        //long ms;
        unsigned int ms, sec, min, hour, day, mon, year;
	struct tm *info;
        time( &rawtime );

        info = localtime( &rawtime );

        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MS_0, &ms);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MS_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_S_0, &sec);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_S_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MIN_0, &min);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MIN_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_HOUR_0, &hour);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_HOUR_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_DAY_0, &day);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_DAY_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MONTH_0, &mon);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_MONTH_0);
        err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_YEAR_0, &year);
        if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_KERNEL_TIME_YEAR_0);

	printf("%d %d %d %d %d %d %d\n", year, mon, day, hour, min, sec, ms);
        printf("Current local time and date: %s", asctime(info));

}
void add_stock_id(unsigned int index, unsigned int upper, unsigned int lower, unsigned int commodity_addr) {
  int err;


  // |-- 						INDIRECTWRDATA 128bit							--|
  // |- -INDIRECTWRDATA_A_HI 32bit- -INDIRECTWRDATA_A_LOW 32bit- -INDIRECTWRDATA_B_HI 32bit- -INDIRECTWRDATA_B_LOW 32bit-	 -|
  // |-- 		IP 		-- 	next_IP 	     -- 	mask 		 -- 	next_port 	      	--|
  uint32_t table_address;
  uint32_t cmd;
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_STOCK_ID_MAPPING_0_ADDRESS;
  //table_address = table_address | 589;
  table_address = table_address | index;
  cmd = (uint32_t)WRITE_CMD;
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, 4);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, upper);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, lower);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, 400);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, commodity_addr);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, 340);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, port);


  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);;
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}
void list_stock_id(void) {
  int i;
  int err;
  unsigned int a, b, c;
  uint32_t table_address;
  uint32_t cmd;
  unsigned int index = 0;
  int count = 0;
  char *str = "1101  ";
  index = one_at_a_time_0(str, 6) % 512;
  for(index=0; index<1024; index++){
  printf("%d\n", index);  
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_STOCK_ID_MAPPING_0_ADDRESS;
  table_address = table_address | index;
  cmd = (uint32_t)READ_CMD;
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &a);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &b);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI, &c);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &valport);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    printf("upper_24 : %u lower_24 : %u\n", a, b);
    if(a!=0 || b!=0 || c!=0)
	count++;
    }
  
    //printf("%d\n", count);
}

void add_commodity_index(unsigned int index, unsigned int commodity_index) {
  int err;


  // |-- 						INDIRECTWRDATA 128bit							--|
  // |- -INDIRECTWRDATA_A_HI 32bit- -INDIRECTWRDATA_A_LOW 32bit- -INDIRECTWRDATA_B_HI 32bit- -INDIRECTWRDATA_B_LOW 32bit-	 -|
  // |-- 		IP 		-- 	next_IP 	     -- 	mask 		 -- 	next_port 	      	--|
  uint32_t table_address;
  uint32_t cmd;
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_COMMODITY_ID_MAPPING_0_ADDRESS;
  //table_address = table_address | 589;
  table_address = table_address | index;
  cmd = (uint32_t)WRITE_CMD;
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, 4);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, commodity_index);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, lower);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, 400);
  //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, commodity_addr);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, 340);
  //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, port);


  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);;
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}
void list_commodity(void) {
  int i;
  int err;
  unsigned int a, b, c;
  uint32_t table_address;
  uint32_t cmd;
  unsigned int index = 0;
  int count = 0;
  char *str = "1101  ";
  for(index=0; index<1550; index++){
  //index = 140;
  printf("%d : ", index);  
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_COMMODITY_ID_MAPPING_0_ADDRESS;
  table_address = table_address | index;
  cmd = (uint32_t)READ_CMD;
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &a);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &b);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI, &c);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &valport);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    printf("%u\n", a);
    if(a!=0)
	count++;
    }
  
    printf("total :%d\n", count);
}

void add_order_index(unsigned int index, unsigned int upper, unsigned int lower) {
  int err;


  // |-- 						INDIRECTWRDATA 128bit							--|
  // |- -INDIRECTWRDATA_A_HI 32bit- -INDIRECTWRDATA_A_LOW 32bit- -INDIRECTWRDATA_B_HI 32bit- -INDIRECTWRDATA_B_LOW 32bit-	 -|
  // |-- 		IP 		-- 	next_IP 	     -- 	mask 		 -- 	next_port 	      	--|
  uint32_t table_address;
  uint32_t cmd;
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_ORDER_ID_MAPPING_0_ADDRESS;
  //table_address = table_address | 589;
  table_address = table_address | index;
  cmd = (uint32_t)WRITE_CMD;
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, 4);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI, upper);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_HI);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, lower);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, 400);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI, extra_bit);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_A_LOW, 340);
  //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_HI);
  //err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTWRDATA_B_LOW, port);


  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
  err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);;
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);
}
void list_order(void) {
  int i;
  int err;
  unsigned int a, b, c;
  uint32_t table_address;
  uint32_t cmd;
  unsigned int index = 0;
  int count = 0;
  int count_sell = 0;
  char *str = "1101  ";
  for(index=0; index<4096; index++){
  //index = 619;
  //printf("%d\n", index);  
  table_address = (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_ORDER_ID_MAPPING_0_ADDRESS;
  table_address = table_address | index;
  cmd = (uint32_t)READ_CMD;
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &a);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &b);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI, &c);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &valport);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    //printf("%u %u\n", a, b);
    if(a!=0 && b!=0)
	count++;
    }
  
    printf("num of buy order : %d\n", count);
  for(index=0; index<4096; index++){
  //index = 619;
  //printf("%d\n", index);  
  table_address = (1<<12) | (uint32_t)SUME_OUTPUT_PORT_LOOKUP_MEM_ORDER_ID_MAPPING_0_ADDRESS;
  table_address = table_address | index;
  cmd = (uint32_t)READ_CMD;
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS, table_address);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTADDRESS);
    err=writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND, cmd);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTCOMMAND);

    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI, &a);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_HI);
    err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW, &b);
    if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_A_LOW);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI, &c);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_HI);
    //err=readReg(sume,SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW, &valport);
    //if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_0_INDIRECTREPLY_B_LOW);
    //printf("%u %u\n", a, b);
    if(a!=0 && b!=0)
	count_sell++;
    }
  
    printf("num of sell order : %d\n", count_sell);
}



void listflag(void) {
  int i;
  int err;
  unsigned int value;
  err = writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0);
  err = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0,&value);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0);



   //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_RD_ADDR_REG, 0);

    //readReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, &value);

    printf("%x\n", value);
}
void setflag(void){

  int err;
  unsigned int value;
  err = writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0, 1);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0);

  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 1);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 0);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);
}

void clearflag(void){
  writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_CONNECT_SIGNAL_0, 0 ); 
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 0);
  // writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);


}
void list_shutdown_flag(void) {
  int i;
  int err;
  unsigned int value;
  err = writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0, 0);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0);
  err = readReg(sume,SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0,&value);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0);



   //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_RD_ADDR_REG, 0);

    //readReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, &value);

    printf("%x\n", value);
}



void set_shutdown_flag(void){

  int err;
  unsigned int value;
  err = writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0, 1);
  if(err) printf("0x%08x: ERROR\n", SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0);

  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 1);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 0);
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);
}

void clear_shutdown_flag(void){
  writeReg(sume,SUME_OUTPUT_PORT_LOOKUP_SHUTDOWN_SIGNAL_0, 0 );
  //writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_ENTRY_VALUE_REG, 0);
  // writeReg(&nf2, ROUTER_OP_LUT_CONNECT_FLAG_TABLE_WR_ADDR_REG, 0);


}


void set_connection(void){
      setflag();
      listflag();
}

void shutdown_connect(void){
      set_shutdown_flag();
      list_shutdown_flag();
}


void read_resend_seq(void){
        unsigned resend_begin;
	unsigned resend_end;
        readReg(sume,SUME_OUTPUT_PORT_LOOKUP_RESEND_BEGIN_FIX_SEQ_NUM_0 , &resend_begin);
        printf("Resend Begin Sequece Number : %d%d%d%d%d%d\n", (resend_begin>>20)&15, (resend_begin>>16)&15, (resend_begin>>12)&15, (resend_begin>>8)&15, (resend_begin>>4)&15, (resend_begin)&15);
        printf("%d\n", resend_begin);

	readReg(sume,SUME_OUTPUT_PORT_LOOKUP_RESEND_END_FIX_SEQ_NUM_0,&resend_end);
        printf("Resend End Sequece Number : %d%d%d%d%d%d\n", (resend_end>>20)&15, (resend_end>>16)&15, (resend_end>>12)&15, (resend_end>>8)&15, (resend_end>>4)&15, (resend_end)&15);
        printf("%d\n", resend_end);
	

	

}

void set_seq(void){
        unsigned int netfpga_seq, fix_server_seq;
        unsigned int wr_value;
        printf("please enter the sequence number:");
        scanf("%d", &wr_value);
        writeReg(sume, SUME_OUTPUT_PORT_LOOKUP_OVERWRITE_FIX_SEQ_NUM_0, wr_value);
	writeReg(sume, SUME_OUTPUT_PORT_LOOKUP_OVERWRITE_FIX_SEQ_NUM_0, 0) ;
        //writeReg(&nf2, ROUTER_OP_LUT_SEQ_TABLE_ENTRY_FIX_SERVER_SEQ_REG, 2);
        //writeReg(sume, ROUTER_OP_LUT_SEQ_TABLE_WR_ADDR_REG, 0);

        //read_seq();
}


