#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>




#define PATHLEN         80
#define NUM_STOCK       1550
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
	init_str_array();
	//hash_table0[0] = "123456";
	//printf("%s", hash_table0[0]);
	loadstrategy();
	//listhashtable();
	return 0;
}
void init_str_array(){
	int i = 0;
	hash_table_0 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_1 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_2 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	hash_table_3 = (char **)malloc((TABLE_SIZE/4) * sizeof(char *));
	for(i=0; i<TABLE_SIZE/4; i++){
		hash_table_0[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_1[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_2[i] = (char *)malloc(sizeof(char) * 7);
		hash_table_3[i] = (char *)malloc(sizeof(char) * 7);
	}
}	

void listhashtable(){
	int i = 0;
	int count = 0;
	for(i=0; i<TABLE_SIZE/4; i++){
		printf("%d : %s	%s	%s	%s\n", i, hash_table_0[i], hash_table_1[i], hash_table_2[i], hash_table_3[i]);
		if(strncmp(hash_table_0[i], "",6) == 0)
			count++;
		if(strncmp(hash_table_1[i], "",6) == 0)
			count++;
		if(strncmp(hash_table_2[i], "",6) == 0)
			count++;
		if(strncmp(hash_table_3[i], "",6) == 0)
			count++;
	}
	printf("%d\n", count);
	/*printf("%s\n", hash_table_1[0]);
	printf("%s\n", hash_table_2[0]);
	printf("%s\n", hash_table_3[0]);*/

}

void loadstrategy(void){
	int i = 0, j = 0, k = 0;
	int count = 0;
	char line[100];
    char *temp = NULL, *num = NULL;
	char price[10], qty[10];
	int   digit;
    //FILE *rd_ptr = fopen("./stock_strategy_load_1118.txt", "r"); 
    //FILE *rd_ptr = fopen("./Stock_ID.txt", "r"); 
    FILE *rd_ptr = fopen("./Commodity.txt", "r"); 
    //FILE *wr_ptr0 = fopen("./hash_index_289.txt", "w"); 
    //FILE *wr_ptr1 = fopen("./hash_id_mapping_289.txt", "w"); 
    
    // generate hash index first
    while(fgets(line, 100, rd_ptr)){
        temp = strtok(line, "\t");
        //if(strncmp(temp, "Stock:", 6) == 0){
            //temp = strtok(NULL, "\t");
		//printf("%s\n", temp);
            if(insert_cuckoo_hashing_four_divide(temp, j) == -1){
		count++;
    		//unsigned int index0 = one_at_a_time_0(temp, 6) % 512;
		//printf("%u\n", index0);
		printf("%s\n", temp);
                printf("Collision occurs at [%d] stock code\n", j);
		printf("hash rate : %f\n", (float)(j-count)/j);
		printf("collision : %d\n", count);
                //return;
            }
            j++;
        //}
    }
    rewind(rd_ptr);
    j = 0;
    count = 0;
	for(j=0; j<1550; j++){
		printf("%d\n", write_index[j]);

	}	
/*    for(j=0; j<1024; j++){
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
    for(j=0; j<1024; j++){
	if(hash_table_vld_1[j] == 1){
		//printf("1\n");
		printf("%d: %s\n", j, hash_table_1[j]);
		count++;
	}
	else{
		printf("%d: NULL\n", j);
		//printf("0\n");
	}
    }
    for(j=0; j<1024; j++){
	if(hash_table_vld_2[j] == 1){
		//printf("1\n");
		printf("%d: %s\n", j, hash_table_2[j]);
		count++;
	}
	else{
		printf("%d: NULL\n", j);
		//printf("0\n");
	}
    }
    for(j=0; j<1024; j++){
	if(hash_table_vld_3[j] == 1){
		//printf("1\n");
		printf("%d: %s\n", j, hash_table_3[j]);
		count++;
	}
	else{
		printf("%d: NULL\n", j);
		//printf("0\n");
	}
    }
    printf("%d\n", count);
*/    // search to ensure all stocks are inserted to hash table
    /*while(fgets(line, 100, rd_ptr)){
        temp = strtok(line, "\t");
        if(strncmp(temp, "Stock:", 6) == 0){
            temp = strtok(NULL, "\t");
            if(search_for_debug(temp) == -1){
                printf("Search error at [%d] stock code\n", j);
                //return;
            }
            j++;
        }
    }*/
 

}

int insert_cuckoo_hashing_four_divide(char *key, int order){
    int  i, j;

    // insert hash function
    unsigned int index0 = one_at_a_time_0(key, 6) % (TABLE_SIZE/4);
    unsigned int index1 = one_at_a_time_1(key, 6) % (TABLE_SIZE/4);
    unsigned int index2 = one_at_a_time_2(key, 6) % (TABLE_SIZE/4);
    unsigned int index3 = one_at_a_time_3(key, 6) % (TABLE_SIZE/4);
    int N = 1024, k = 0, run = i, temp;
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
        else if(hash_table_vld_2[index2] == 0){
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
        }
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
            index2 = one_at_a_time_2(key, 6) % (TABLE_SIZE/4);
            index3 = one_at_a_time_3(key, 6) % (TABLE_SIZE/4);
        }
        k++;
    }
    return -1;
}


int search_for_debug(char *key){
    unsigned int index0 = one_at_a_time_0(key, 6) % (TABLE_SIZE/4);
    unsigned int index1 = one_at_a_time_1(key, 6) % (TABLE_SIZE/4);
    unsigned int index2 = one_at_a_time_2(key, 6) % (TABLE_SIZE/4);
    unsigned int index3 = one_at_a_time_3(key, 6) % (TABLE_SIZE/4);
    if(strncmp(hash_table_0[index0], key, 6) != 0 && strncmp(hash_table_1[index1], key, 6) != 0 &&
       strncmp(hash_table_2[index2], key, 6) != 0 && strncmp(hash_table_3[index3], key, 6) != 0){
        return -1;
    }
    return 1;
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


