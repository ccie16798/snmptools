#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Mahmoud Basset Technologies */

/**
 * en fonction d'un seul octet et de son offset dans la chaine 
 * de caractere imprime la liste des vlans
 */
void char_to_vlans(unsigned char c, int offset) {
	int i;
	unsigned char mask = 0x80;

	for (i=0; i<8; i++) {
		if (c & mask)		
			printf("%d ",i + offset*8);
		mask = mask/2;
	}
}

/**
 * detecte si tous les vlan sont propages sur le trunk
 * dans ce cas String == 7F FF FF FF FF FF ........
 */
int all_vlans(char *str) {
	if (*str!='7')
		return 0;
	str++;
	while (*str != '\0' ) {
		if (*str != 'F' && *str != ' ')
			return 0;
		str++;
	}
	return 1;
}

/**
 * cette fonction va traiter une seul ligne du fichier
 */
int bitmap(char *input) {
	char *s;
	int i=0;
	unsigned char c;

	if (all_vlans(input) != 0) {
		printf("ALL\n");
		return 0;
	}
	s = strtok(input, " \n");

	while (s!=NULL) {
		sscanf(s,"%x",&c);
		//printf("%x\n", c);
		char_to_vlans(c, i);
		s = strtok(NULL, " \n");
		i++;
	}
	printf("\n");
	return 0;
}

int main(int argc, char **argv) {
	char buffer[4*1024];

	if (argv[1] != NULL)
		/** juste pour tester; la bonne methode est d'utiliser le standard input */
		bitmap(argv[1]);
	else {
		while (fgets(buffer,sizeof(buffer),stdin) != NULL) {
			/** fgets ne vire pas le \n final */
			buffer[strlen(buffer)-1]='\0';
			bitmap(buffer);
		}
	}
	exit(0);
}
