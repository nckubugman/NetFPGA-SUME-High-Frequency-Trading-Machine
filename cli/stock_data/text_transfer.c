#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


int main(){
	char line[100];
	char prev[10] = "0";
	char *temp = NULL, *temp2 = NULL;
	int  max = 0, count = 0, m = -1, i = 0;
	int  endpoint = 0;
	int  count_table[289] = {};
        int  count_distributed[50] = {};
	FILE *rd_ptr = fopen("./kgi_Commodity.txt", "r");
        //FILE *wr_ptr0 = fopen("./stock_ID.txt", "w");
        temp = malloc(sizeof(char) * 11);	
	

	while(fgets(line, 100, rd_ptr)){
		temp = strtok(line, "\t");
        	if(strncmp(temp, prev, 10) != 0){
			if((m > 0 && m < 7) || (m == 8) || (m > 10 && m < 15))
				printf("\n%s\t", temp);
			else if(m == 7 || m == 9 || m == 10)
				printf("\n%s \t", temp);
			else
				printf("\n%s  \t", temp);
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
			if((m > 0 && m < 7) || (m == 8) || (m > 10 && m < 15))
				printf("\n%s\t", temp);
			else if(m == 7 || m == 9 || m == 10)
				printf("\n%s \t", temp);
			else
				printf("\n%s  \t", temp);
			count++;
		}
		temp2 = strtok(NULL, "\n");
		printf("%s\t", temp2);
		int n = strlen(temp) + 1;
		strncpy(prev, temp, n);
	}
	count_table[m] = count;
	fclose(rd_ptr);
	/*for(i = 0; i < 289; i++)
		printf("Stock_ID %d : %d\n", i+1, count_table[i]);
	for(i=0; i<50; i++)
		printf("%d\n", count_distributed[i]);
	printf("Max # of Commodity = %d\n", max);*/
        //fclose(wr_ptr0);

	
	return 0;
}

