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
	cat .svn/svnxstage | sed '/^$/d' | tr '\n' '\0' | xargs -0 svn commit "$@"

	if [ "$?" = "0" ]; then
		rm .svn/svnxstage
	fi
}



cmdDiff() {

	checkRepo

	if [[ -f "$1" || -d "$1" ]] ; then
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
				cat .svn/svnxstage | tr '\n' ' ' | xargs svn diff --depth empty --diff-cmd diff -x -uw | less
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
			echo ""
			echo "Valid options:"
			echo "  -s    : show staged files only"
			echo "  -m    : show unstaged modified files only"
			echo "  -u    : show untracked files only"
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
					printSvnFile "$line"
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
	if [ -e "$1" ]; then
		getSvnModFiles
		while read -r line; do
			if [ "$line" = "$1" ]; then
				echo "File staged:"
				echo "$line" >> .svn/svnxstage
				sort -o .svn/svnxstage -u .svn/svnxstage
				printSvnFile "$line"
				exit;
			fi
		done <<< "$SVNFILES"
	fi

	#Stage file deletion
	if [ ! -e "$1" ]; then
		getSvnDelFiles
		while read -r line; do
			if [ "$line" = "$1" ]; then
				echo "File staged:"
				echo "$line" >> .svn/svnxstage
				printSvnFile "$line"
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

	show=""
	#Process options
	while getopts ":smu" FLAG
	do
		show="$FLAG"
	done
	shift $((OPTIND-1))

	#Staging changes
	if [ "$show" = "" ] || [ "$show" = "s" ]; then

		echo "Changes to be committed:"
		printStagedFiles
		echo ""
	fi

	
	#Non staged changes
	if [ "$show" = "" ] || [ "$show" = "m" ]; then
		echo "Changed but not updated:"
		printModFiles
		echo ""
	fi

	if [ "$show" = "" ] || [ "$show" = "u" ]; then
		#New files
		echo "Untracked files:"
		printNewFiles
		echo ""
	fi
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
				printSvnFile "$line"
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
	SVNFILES=`svn status | sed -e 's/^........//' | sort`
}

getSvnNewFiles() {
	SVNFILES=`svn status | grep '^\?' | sed -e 's/^........//' | sort`
}

getSvnModFiles() {
	SVNFILES=`svn status | grep -v '^\?' | sed -e 's/^........//' | sort`
}

getSvnDelFiles() {
	SVNFILES=`svn status | grep '^D' | sed -e 's/^........//' | sort`
}

printSvnFile() {
	if [ "$1" != "" ]; then
		#Need to pipe through cat else get a broken pipe error
		svn status --depth empty "$1" | cat | head -n 1
	fi
}

printSvnFiles() {
	if [ "$1" != "" ]; then
		svn status --depth empty "$1" | cat
	fi
}

printStagedFiles() {

	if [ -f  .svn/svnxstage ]; then

		cat .svn/svnxstage | grep -v '^\s*$' | sort | tr '\n' '\0' | xargs -0 svn status --depth empty

		#getStagedFiles
		#while read -r line; do
		#	printSvnFile "$line"
		#done <<< "$STAGEFILES"
	fi
}

printModFiles() {

	

	getSvnModFiles
	if [ "$SVNFILES" != "" ]; then
		if [ -f .svn/svnxstage ]; then
		
			getStagedFiles
			
			UNSTAGED=`comm -23 <(echo "$SVNFILES") <(echo "$STAGEFILES")`
			echo "$UNSTAGED" | sort | tr '\n' '\0' | xargs -0 svn status --depth empty

#			while read -r line; do
#		
#				passed="0"
#				while read -r file; do
#					if [ "$line" = "$file" ]; then
#						passed="1"
#						continue
#					fi
#				done <<< "$STAGEFILES"
#		
#				if [ "$passed" = "0" ]; then
#					printSvnFile "$line"
#				fi
#		
#			done <<< "$SVNFILES"
		else
			cat "$SVNFILES" | sort | tr '\n' '\0' | xargs -0 svn status --depth empty
			#while read -r line; do
			#	printSvnFile "$line"
			#done <<< "$SVNFILES"
		fi
	fi
}

printNewFiles() {
	getSvnNewFiles
	echo "$SVNFILES" | sort | tr '\n' '\0' | xargs -0 svn status --depth empty
#	while read -r line; do
#		printSvnFile "$line"
#	done <<< "$SVNFILES"
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





