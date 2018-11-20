#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>




#define PATHLEN         80
#define NUM_STOCK       1118
#define TABLE_SIZE      4096

void loadstrategy(void);
void listhashtable(void);


void init_str_array();
int  insert_cuckoo_hashing_four_divide(char *key, int order);
int  search_for_debug(char *key);
unsigned int one_at_a_time_0(char *key, int len);
unsigned int one_at_a_time_1(char *key, int len);
unsigned int one_at_a_time_2(char *key, int len);
unsigned int one_at_a_time_3(char *key, int len);

// --- global variable 
/*char hash_table_0         [TABLE_SIZE/4][7] = {'\0'};
char hash_table_1         [TABLE_SIZE/4][7] = {'\0'};
char hash_table_2         [TABLE_SIZE/4][7] = {'\0'};
char hash_table_3         [TABLE_SIZE/4][7] = {'\0'};*/
char **hash_table_0;
char **hash_table_1;
char **hash_table_2;
char **hash_table_3;
int  hash_table_vld_0     [TABLE_SIZE/4] = {0};
int  hash_table_vld_1     [TABLE_SIZE/4] = {0};
int  hash_table_vld_2     [TABLE_SIZE/4] = {0};
int  hash_table_vld_3     [TABLE_SIZE/4] = {0};
int  write_index          [NUM_STOCK]    = {0}; // stock code map to hash table index
int  stock_order          [TABLE_SIZE]   = {0}; // hash table store original order of stock list


int main(){
	//init_str_array();
	//hash_table0[0] = "123456";
	//printf("%s", hash_table0[0]);
	loadstrategy();
	//listhashtable();
	return 0;
}

int groupping(unsigned long long stock_id, int g1, int g2, int g3, int g4, int g5, int g6, int g7, int g8, int g9){
	int group_table[512] = {};
	int temp = 0;
	temp += (stock_id >> g9) & 1;
	temp <<= 1;
	temp += (stock_id >> g8) & 1;
	temp <<= 1;
	temp += (stock_id >> g7) & 1;
	temp <<= 1;
	temp += (stock_id >> g6) & 1;
	temp <<= 1;
	temp += (stock_id >> g5) & 1;
	temp <<= 1;
	temp += (stock_id >> g4) & 1;
	temp <<= 1;
	temp += (stock_id >> g3) & 1;
	temp <<= 1;
	temp += (stock_id >> g2) & 1;
	temp <<= 1;
	temp += (stock_id >> g1) & 1;
	return temp;
}

int groupping_2(unsigned long long stock_id, int g1, int g2, int g3, int g4, int g5, int g6, int g7, int g8, int g9, int g10){
	int group_table[512] = {};
	int temp = 0;
	temp += (stock_id >> g10) & 1;
	temp <<= 1;
	temp += (stock_id >> g9) & 1;
	temp <<= 1;
	temp += (stock_id >> g8) & 1;
	temp <<= 1;
	temp += (stock_id >> g7) & 1;
	temp <<= 1;
	temp += (stock_id >> g6) & 1;
	temp <<= 1;
	temp += (stock_id >> g5) & 1;
	temp <<= 1;
	temp += (stock_id >> g4) & 1;
	temp <<= 1;
	temp += (stock_id >> g3) & 1;
	temp <<= 1;
	temp += (stock_id >> g2) & 1;
	temp <<= 1;
	temp += (stock_id >> g1) & 1;
	return temp;
}

int groupping_3(unsigned long long stock_id, int g1, int g2, int g3, int g4, int g5, int g6, int g7, int g8, int g9, int g10, int g11){
	int group_table[512] = {};
	int temp = 0;
	temp += (stock_id >> g11) & 1;
	temp <<= 1;
	temp += (stock_id >> g10) & 1;
	temp <<= 1;
	temp += (stock_id >> g9) & 1;
	temp <<= 1;
	temp += (stock_id >> g8) & 1;
	temp <<= 1;
	temp += (stock_id >> g7) & 1;
	temp <<= 1;
	temp += (stock_id >> g6) & 1;
	temp <<= 1;
	temp += (stock_id >> g5) & 1;
	temp <<= 1;
	temp += (stock_id >> g4) & 1;
	temp <<= 1;
	temp += (stock_id >> g3) & 1;
	temp <<= 1;
	temp += (stock_id >> g2) & 1;
	temp <<= 1;
	temp += (stock_id >> g1) & 1;
	return temp;
}

void loadstrategy(void){
	int i = 0, j = 0, k = 0;
	int group_1 = 0, group_2 = 0, group_3 = 0, group_4 = 0, group_5 = 0, group_6 = 0, group_7 = 0, group_8 = 0, group_9 = 0, group_10 = 0, group_11 = 0;
	int group_table[1024] = {};
	unsigned long long stock_val[289] = {};
	unsigned long long val = 0;
	int count = 0;
	char line[100];
    char *temp = NULL, *num = NULL;
	char price[10], qty[10];
	int   digit;
	int index = 0;
	int flag = 0;
    //FILE *rd_ptr = fopen("./stock_strategy_load_1118.txt", "r"); 
    FILE *rd_ptr = fopen("./Stock_ID.txt", "r"); 
    //FILE *rd_ptr = fopen("./Commodity.txt", "r"); 
    //FILE *wr_ptr0 = fopen("./hash_index_289.txt", "w"); 
    //FILE *wr_ptr1 = fopen("./hash_id_mapping_289.txt", "w"); 
    
    while(fgets(line, 100, rd_ptr)){
        temp = strtok(line, "\t");
	stock_val[j] += temp[0];
	stock_val[j] <<= 8;
	stock_val[j] += temp[1];
	stock_val[j] <<= 8;
	stock_val[j] += temp[2];
	stock_val[j] <<= 8;
	stock_val[j] += temp[3];
	stock_val[j] <<= 8;
	stock_val[j] += temp[4];
	stock_val[j] <<= 8;
	stock_val[j] += temp[5];
	//val = temp[0]<<40 + temp[1]<<32 + temp[2]<<24 + temp[3]<<16 + temp[4]<<8 + temp[5];
	//printf("%c%c%c%c%c%c\n", temp[0], temp[1], temp[2], temp[3], temp[4], temp[5]);
	//printf("%u %u %u %u %u %u\n", temp[0], temp[1], temp[2], temp[3], temp[4], temp[5]);
	//printf("%llu\n", stock_val[j]);
	j++;
    }
    rewind(rd_ptr);
    j = 0;
    //printf("%d\n", groupping(1265, 0, 1, 2, 3, 4, 5, 6, 7, 8));
    // generate hash index first
    for(group_1 = 0; group_1 < 48; group_1++){
    	for(group_2 = group_1 + 1; group_2 < 48; group_2++){
    		for(group_3 = group_2 + 1; group_3 < 48; group_3++){
    			for(group_4 = group_3 + 1; group_4 < 48; group_4++){
    				for(group_5 = group_4 + 1; group_5 < 48; group_5++){
    					for(group_6 = group_5 + 1; group_6 < 48; group_6++){
    						for(group_7 = group_6 + 1; group_7 < 48; group_7++){
    							for(group_8 = group_7 + 1; group_8 < 48; group_8++){
    								for(group_9 = group_8 + 1; group_9 < 48; group_9++){
									for(group_10 = group_9 + 1; group_10 < 48; group_10++){
										for(group_11 = group_10 + 1; group_11 < 48; group_11++){
											for(i=0; i<289; j++){
												index = groupping_3(stock_val[j], group_1, group_2, group_3, group_4, group_5, group_6, group_7, group_8, group_9, group_10, group_11);
												if(group_table[index] == 0)
													group_table[index] = 1;
												else{	
													flag = 1;	
													break;										
												}
											}
											for(j=0; j<512; j++)
												group_table[j] = 0;
											if(flag == 0){
												count += 1;
												printf("%d %d %d %d %d %d %d %d %d\n", group_1, group_2, group_3, group_4, group_5, group_6, group_7, group_8, group_9);
											}
											flag = 0;
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
    }
    /*for(j=0; j<289; j++){
	printf("%llu\n", stock_val[j]);
    }*/
	printf("TOTAL :%d\n", count);
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


