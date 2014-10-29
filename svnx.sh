#!/bin/bash

##
#
# Copyright (c) 2011 Cimaron Shanahan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
##

##
#
# Commit Command
#
# Send files in staging area to the repository.
#
##
cmdCommit() {

	checkRepo

	getStagedFiles
	
	cat .svn/svnxstage | tr '\n' ' ' | xargs svn commit "$@"

	if [ "$?" = "0" ]; then
		rm .svn/svnxstage
	fi
}



cmdDiff() {

	checkRepo

	if [ -f "$1" ]; then
		svn diff --diff-cmd diff -x -uw "$1" | less
		exit;
	fi

	local OPTIND FLAG cmd
	
	while getopts ":sua" FLAG
	do
		#echo $FLAG
		case "$FLAG" in
			a)
				svn diff --diff-cmd diff -x -uw | less
				exit;
				;;
			s)
				cat .svn/svnxstage | tr '\n' ' ' | xargs svn diff --diff-cmd diff -x -uw | less
				exit;
				;;
			u)
				echo "Not implemented yet."
				exit;
				;;
		esac
	done
	shift $((OPTIND-1))

	svn diff --diff-cmd diff -x -uw | less
	exit;

}

cmdHelp() {

	if [ "$1" = "" ]; then
		echo "usage: svnx <subcommand> [options] [args]"
		echo "Type 'svnx help <subcommand>' for help on a specific subcommand."
		echo "Available subcommands:"
		echo "    commit"
		echo "    diff"
		echo "    stage"
		echo "    status"
		echo "    unstage"
		exit
	else
	case "$1" in

		commit)
			echo "commit: Send files in staging area to the repository."
			echo "usage: commit"
			;;

		diff)
			echo "diff: Display the differences between two revisions or paths."
			echo ""
			echo "Valid options:"
			;;

		stage)
			echo "stage: Edit files in staging area."
			echo "usage: stage [PATH...]"
			echo ""
			echo "Valid options:"
			echo "  -r    : reset staging area"
			echo "  -m    : add all modified files to staging area"
			echo "  -e    : edit staging area in editor"
			;;

		status)
			echo "status: Print the status of working copy files and directories."
			echo "usage: status"
			;;

		unstage)
			echo "unstage: Remove files from staging area."
			echo "usage: unstage [PATH...]"
			echo ""
			echo "Valid options:"
			;;

		*)
			echo "'$1': unknown command."
			exit 1
	esac
	fi
}


cmdStage() {

	checkRepo

	local OPTIND FLAG cmd
	
	#Interactive editing
	if [ "$#" = "0" ]; then
		nano .svn/svnxstage
		echo "Staging area updated."
		exit;
	fi
	
	#Process options
	while getopts ":erm" FLAG
	do
		#echo $FLAG
		case "$FLAG" in
			m)
				getSvnModFiles
				echo "$SVNFILES" > .svn/svnxstage
				while read -r line; do
					svn status "$line"
				done <<< "$SVNFILES"
				;;
			e)
				nano .svn/svnxstage
				echo "Staging area updated."
				;;
			r)
				if [ -f .svn/svnxstage ]; then
					rm .svn/svnxstage
				fi
				echo "Staging area cleared."
				;;
		esac
	done
	shift $((OPTIND-1))

	#Stage file
	if [ -f "$1" ]; then
		getSvnModFiles
		while read -r line; do
			if [ "$line" = "$1" ]; then
				echo "File staged:"
				echo "$line" >> .svn/svnxstage
				svn status "$line"
				exit;
			fi
		done <<< "$SVNFILES"
	fi

	#Stage file deletion
	if [ ! -f "$1" ]; then
		getSvnDelFiles
		while read -r line; do
			if [ "$line" = "$1" ]; then
				echo "File staged:"
				echo "$line" >> .svn/svnxstage
				svn status "$line"
				exit;
			fi
		done <<< "$SVNFILES"
	fi

	exit;
}


##
#
# Status Command
#
# Displays contents of staging area and svn status
# Valid Options:
#   -r    : reset staging area
#   -a    : add all modified files to staging area
#
##
cmdStatus() {

	checkRepo

	#Staging changes
	echo "Changes to be committed:"
	if [ -f  .svn/svnxstage ]; then
		getStagedFiles
		while read -r line; do
			svn status "$line"
		done <<< "$STAGEFILES"
	fi
	echo ""

	#Non staged changes
	echo "Changed but not updated:"
	getSvnModFiles
	if [ "$SVNFILES" != "" ]; then
		if [ -f .svn/svnxstage ]; then
	
			getStagedFiles
			while read -r line; do
	
				passed="0"
				while read -r file; do
					if [ "$line" = "$file" ]; then
						passed="1"
						continue
					fi
				done <<< "$STAGEFILES"
	
				if [ "$passed" = "0" ]; then
					svn status "$line"
				fi
	
			done <<< "$SVNFILES"
		else
			while read -r line; do
				svn status "$line"
			done <<< "$SVNFILES"
		fi
	fi
	echo ""

	#New files
	echo "Untracked files:"
	
	getSvnNewFiles
	while read -r line; do
		svn status "$line"
	done <<< "$SVNFILES"	
}


##
#
# Unstage Command
#
# Remove files from staging area.
# Valid Options:
#
##
cmdUnstage() {

	checkRepo

	#Unstage file
	if [ -f "$1" ]; then
		getStagedFiles
		echo "" > .svn/svnxstage

		while read -r line; do
			if [ "$line" = "$1" ]; then
				echo "File unstaged:"
				svn status "$line"
			else
				echo "$line" >> .svn/svnxstage				
			fi
		done <<< "$STAGEFILES"
	fi

	exit;
}



checkRepo() {
	if [ ! -d .svn ]; then
		echo "svnx: warning: '.' is not a working copy"
		exit
	fi	
}

getStagedFiles() {
	STAGEFILES=`cat .svn/svnxstage | grep -v '^\s*$'`
}

getSvnAllFiles() {
	SVNFILES=`svn status | sed -e 's/^........//'`
}

getSvnNewFiles() {
	SVNFILES=`svn status | grep '^\?' | sed -e 's/^........//'`
}

getSvnModFiles() {
	SVNFILES=`svn status | grep -v '^\?' | sed -e 's/^........//'`
}

getSvnDelFiles() {
	SVNFILES=`svn status | grep '^D' | sed -e 's/^........//'`
}



cmd_args=("$@")


case "$1" in

	commit)
		shift
		cmdCommit "$@"
		;;

	diff)
		shift
		cmdDiff "$@"
		;;
	
	help)
		cmdHelp $2
		;;

	stage)
		shift
		cmdStage "$@"
		;;

	status)
		shift
		cmdStatus "$@"
		;;

	unstage)
		shift
		cmdUnstage "$@"
		;;

	*)

		echo "Type 'svnx help' for usage."
		
esac





