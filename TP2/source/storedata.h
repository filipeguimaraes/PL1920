#ifndef __STORE_DATA_H__
#define __STORE_DATA_H__

#include "glib.h"
#include "gmodule.h"


typedef struct storedata_st * STOREDATA;



STOREDATA store_data_new_table (char * k);

STOREDATA store_data_new_array (char * k);

STOREDATA store_data_new (char t, char * k, gpointer d);

void store_data_set_data (STOREDATA sd, gpointer d);

gpointer store_data_get_data (STOREDATA sd);

void store_data_set_key (STOREDATA sd, char * k);

char * store_data_get_key (STOREDATA sd);

void store_data_set_type (STOREDATA sd, char t);

char store_data_get_type (STOREDATA sd);

STOREDATA store_data_next_key (STOREDATA sd, char * next_key);

STOREDATA store_data_next_key_value (STOREDATA sd, char * next_key);

int store_data_set_value (STOREDATA sd, char t, char * k, gpointer d);

int store_data_add_value (STOREDATA sd, STOREDATA v);

void print_2_JSON (STOREDATA s);

void print_2_XML (STOREDATA s);

#endif //__STORE_DATA_H__
