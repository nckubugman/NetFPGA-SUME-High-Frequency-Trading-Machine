#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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

int main(){
	char line[100];
	char prev[10] = "0";
	char *temp = NULL, *temp2 = NULL;
	int  max = 0, count = 0, m = -1, i = 0;
	unsigned long long endpoint = 0;
	unsigned long long addr = 0;
	int  count_table[289] = {};
        int  count_distributed[50] = {};
	FILE *rd_ptr = fopen("./kgi_commodity_fix.txt", "r");
        //FILE *rd_ptr = fopen("./Stock_ID.txt", "r");
        temp = malloc(sizeof(char) * 11);	
	

	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			/*if((m > 0 && m < 7) || (m == 8) || (m > 10 && m < 15))
				printf("\n%s\t", temp);
			else if(m == 7 || m == 9 || m == 10)
				printf("\n%s \t", temp);
			else
				printf("\n%s  \t", temp);*/
			if(count > max)
				max = count;
			if(m != -1){
				count_table[m] = count;
				count_distributed[count]++;
			}
			m++;
			count = 1;
		}
		else{
			count++;
		}
		/*temp2 = strtok(NULL, "\n");
		printf("%s\t", temp2);*/
		int n = strlen(temp) + 1;
		strncpy(prev, temp, n);
	}
	count_table[m] = count;
	rewind(rd_ptr);
	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			//endpoint += count_table[i];
			//printf("%u\t%d\t%d\n", temp, endpoint, endpoint+count_table[i]-1);
			addr = endpoint<<11; 
			addr = addr + endpoint + count_table[i] - 1;
			printf("%u\t%u\t%llu\n", stock_id_msb24(temp), stock_id_lsb24(temp), addr);
			endpoint += count_table[i];
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

