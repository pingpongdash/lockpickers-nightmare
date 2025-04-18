if [[ $- != *i* ]] ; then
	# Shell is non-interactive.  Be done now!
	return
fi

# set fallback PS1; only if currently set to upstream bash default
if [ "$PS1" = '\s-\v\$ ' ]; then
	PS1='\h:\w\$ '
fi

for f in /etc/bash/*.sh; do
	[ -r "$f" ] && . "$f"
done
unset f

PS1="$(whoami)@blue-oyster \$ "
trap '' INT

LOGFILE="/var/log/blue-oyster-log/cmd.log"

max_count=12
count=0

alias mount="mount | grep -v overlay | grep -v mapper "

while true; do
  read -e -p "$PS1" cmd
  echo "$(date +"%F %T") $count: $cmd" >> "$LOGFILE"

  case $cmd in
    "exit") fortune ;;
    # *) fortune ;;
    *) eval "$cmd" ;;
  esac

  ((count++))
  if [[ "$count" == "$max_count" ]]; then
      cat /dev/urandom
  fi
done

