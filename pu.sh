# Author: Claudio Marforio
# E-mail: marforio@gmail.com

# Usage: pu.sh projects_dir
#       | $0  |    $1      |


#!/bin/bash

if [[ $# != 1 ]]; then
	echo "Usage: pu.sh \"projects directory\""
	echo "Example: pu.sh ~/Documents/projects/"
	exit
fi

# return values for checking which versioning system is in use
RET_VALUE_SVN=250
RET_VALUE_GIT=251

# global variables for summary
declare -a SVN_UPDATE
declare -a SVN_WARNING
declare -a SVN_ERRORS
declare -a GIT_UPDATE
declare -a GIT_WARNING
declare -a GIT_ERRORS
REPO_CHECKED=0
working_chars=('|' '/' '-' '\')

# main dir
function main {
	if [[ "$1" == "." || "$1" == "./" ]]; then
		main `pwd`
	fi
	if test -e "$1"; then
		for i in `ls -F "$1"`; do
			if test -d "$1$i"; then
				check_repo "$1$i"
			fi
		done
	else
		echo "$1 doesn't exist, exiting"
		exit
	fi
}

# check_repo dir
function check_repo {
	index=$(($REPO_CHECKED % ${#working_chars[@]}))
	echo -n -e "\rscript is working: ${working_chars[$index]} checked $REPO_CHECKED repositories"
	check_svn "$1"
	if [[ $? == $RET_VALUE_SVN ]]; then
		REPO_CHECKED=$(($REPO_CHECKED + 1))
		#echo -e "\t------ SVN ------"
		cd "$1"
		changed=`svn st`
		if [[ $changed == "" ]]; then
			#echo -e "Updating: $1"
			update_result=`svn update`
			update_worked=`echo $update_result | grep "At revision"`
			if [[ $update_worked == "" ]]; then
				SVN_UPDATE[${#SVN_UPDATE[@]}]="$1"
			fi
			#echo $update_result
		else
			#echo -e "WARNING: $1 contains uncommited changes, please check it manually"
			SVN_WARNING[${#SVN_WARNING[@]}]="$1"
		fi
		#echo -e "\t------ DONE ------\n"
		return;
	fi
	check_git "$1"
	if [[ $? == $RET_VALUE_GIT ]]; then
		REPO_CHECKED=$(($REPO_CHECKED + 1))
		#echo -e "\t------ GIT ------"
		cd "$1"
		# check if user hasn't changed anything
		changed=`git st | grep "nothing to commit"`
		if [[ $changed != "" ]]; then
			#echo -e "Updating: $1"
			pull_st=`git pull 2>/tmp/pu_status`
			pull_result=$(</tmp/pu_status)
			rm /tmp/pu_status
			pull_worked=`echo $pull_st | grep "Already up-to-date."`
			if [[ $pull_worked == "" ]]; then
				pull_worked=`echo $pull_result | grep "fatal"`
				if [[ $pull_worked != "" ]]; then
					GIT_ERRORS[${#GIT_ERRORS[@]}]="$1"
				else
					GIT_UPDATE[${#GIT_UPDATE[@]}]="$1"
				fi				
			fi
			#echo $pull_result
		else
			#echo -e "WARNING: $1 contains uncommited changes, please check it manually"
			GIT_WARNING[${#GIT_WARNING[@]}]="$1"
		fi
		#echo -e "\t------ DONE ------\n"
		return;
	fi
	if [[ $? == 0 ]]; then
		main "$1"
	fi
}

# check_svn dir
function check_svn {
	if test -e "$1/.svn"; then
		return $RET_VALUE_SVN
	else
		return 0
	fi
}

# check_git dir
function check_git {
	if test -e "$1/.git"; then
		return $RET_VALUE_GIT
	else
		return 0
	fi
}

# summary
function summary {
	echo -e "\r                                                             " #remove the "script is working:"
	echo
	echo "Repositories checked: $REPO_CHECKED"
	echo
	if [[ ${#SVN_UPDATE[@]} != 0 ]]; then
		echo "-> SVN UPDATED"
		for (( i=0; i<${#SVN_UPDATE[@]}; i++ )); do
			echo -e "\t ${SVN_UPDATE[$i]}"
		done
		echo
	fi
	if [[ ${#GIT_UPDATE[@]} != 0 ]]; then
		echo "-> GIT UPDATED"
		for (( i=0; i<${#GIT_UPDATE[@]}; i++ )); do
			echo -e "\t ${GIT_UPDATE[$i]}"
		done
		echo
	fi
	if [[ ${#SVN_WARNING[@]} != 0 ]]; then
		echo "-> SVN WARNINGS (check folders, uncommited changes)"
		for (( i=0; i<${#SVN_WARNING[@]}; i++ )); do
			echo -e "\t ${SVN_WARNING[$i]}"
		done
		echo
	fi
	if [[ ${#GIT_WARNING[@]} != 0 ]]; then
		echo "-> GIT WARNINGS (check folders, uncommited changes)"
		for (( i=0; i<${#GIT_WARNING[@]}; i++ )); do
			echo -e "\t ${GIT_WARNING[$i]}"
		done
		echo
	fi
	if [[ ${#GIT_ERRORS[@]} != 0 ]]; then
		echo "-> GIT ERRORS (git repository non reachable or nonexistent?)"
		for (( i=0; i<${#GIT_ERRORS[@]}; i++ )); do
			echo -e "\t ${GIT_ERRORS[$i]}"
		done
	fi
	echo
}

main $1 2>/dev/null
summary
