/*
 *  BOHelperInstaller.c
 *  BootChamp
 *
 *  Created by Kevin Wojniak on 6/26/10.
 *  Copyright 2010 Kevin Wojniak. All rights reserved.
 *
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libgen.h>
#include <copyfile.h>
#include <errno.h>
#include <grp.h>
#include "BOHelperInstaller.h"

int main(int argc, char *argv[])
{
	if (geteuid() != 0) {
		fprintf(stdout, "Must be run as root.\n");
		return EXIT_FAILURE;
	}
	if (argc < 3) {
		fprintf(stdout, "Invalid number of arguments.\n");
		return EXIT_FAILURE;
	}
	const char *src = argv[1];
	const char *dest = argv[2];
	char *parent_dir = dirname((char *)dest);
	struct stat buf;
	while (stat(parent_dir, &buf) != 0) {
		if (mkdir(parent_dir, S_IRWXU | S_IRWXG | S_IRWXO) != 0)
			return errno;
		parent_dir = dirname(parent_dir);
	}
	if (copyfile(src, dest, NULL, COPYFILE_ALL | COPYFILE_UNLINK) != 0) {
		fprintf(stdout, "copy failed %s (%d).\n", strerror(errno), errno);
		return EXIT_FAILURE;
	}
	struct group *admin = getgrnam("admin");
	if (chown(dest, 0, admin ? admin->gr_gid : 0) != 0) {
		fprintf(stdout, "chown failed %s (%d).\n", strerror(errno), errno);
		return EXIT_FAILURE;
	}
	if (chmod(dest, TOOL_MODE) != 0) {
		fprintf(stdout, "chmod failed %s (%d).\n", strerror(errno), errno);
		return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}
