/*
 *  bcbless.c
 *  BootChamp
 *
 *  Created by Kevin Wojniak on 9/5/08.
 *  Copyright 2008-2010 Kevin Wojniak. All rights reserved.
 *
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <spawn.h>
#include <fcntl.h>
#include <errno.h>

int main(int argc, char *argv[])
{
	if (geteuid() != 0) {
		fprintf(stdout, "Must be run as root.\n");
		return EXIT_FAILURE;
	}
	
	if (argc < 5) {
		fprintf(stdout, "Invalid number of arguments.\n");
		return EXIT_FAILURE;
	}
	
	if ((strcmp(argv[1], "-device") && strcmp(argv[1], "-folder")) || strcmp(argv[3], "-nextonly") || (strcmp(argv[4], "yes") && strcmp(argv[4], "no"))) {
		fprintf(stdout, "Bad arguments.\n");
		return EXIT_FAILURE;
	}
	
	char *media_arg = argv[1];
	char *media_val = argv[2];
	char *nextonly = argv[4];
	const int max_args = 8;
	char *args[max_args];
	bzero(args, max_args);
	int a = 0;
	args[a++] = "/usr/sbin/bless";
	if (strcmp(nextonly, "yes") == 0)
		args[a++] = "--nextonly";
	args[a++] = "--verbose";
	args[a++] = "--legacy";
	args[a++] = "--setBoot";
	args[a++] = strcmp(media_arg, "-device") == 0 ? "--device" : "--mount";
	args[a++] = media_val;
	args[a] = NULL;
	
	// TODO: figure out a way to use a pipe instead of writing to file!
	const char *out_path = "/var/tmp/BOHelper";
	posix_spawn_file_actions_t actions;
	if (posix_spawn_file_actions_init(&actions) != 0) {
		fprintf(stdout, "posix_spawn_file_actions_init() failed: %s (%d)\n", strerror(errno), errno);
		return EXIT_FAILURE;
	}
	posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, out_path, O_CREAT|O_WRONLY, 0);

	pid_t pid;
	extern char **environ;
	int ret = posix_spawn(&pid, args[0], &actions, NULL, args, environ);
	posix_spawn_file_actions_destroy(&actions);
	if (ret != 0) {
		fprintf(stdout, "posix_spawn() failed: %s (%d)\n", strerror(errno), errno);
		return EXIT_FAILURE;
	}
	
	int file = open(out_path, O_RDONLY);
	if (file) {
		char buf[512];
		ssize_t buf_len = 0;
		ssize_t bytes = 0;
		while ((bytes = read(file, buf, sizeof(buf)-1)) > 0) {
			buf_len += bytes;
			buf[bytes] = 0;
			fprintf(stdout, "%s", buf);
		}
		close(file);
	}
	unlink(out_path);
	
	int status;
	waitpid(pid, &status, 0);
	if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
		fprintf(stdout, "Bless failed\n");
		return EXIT_FAILURE;
	}
	
    return EXIT_SUCCESS;
}

