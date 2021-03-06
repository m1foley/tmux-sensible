#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ALMOST_SENSIBLE_OPTION="@almost-sensible"

is_osx() {
	local platform=$(uname)
	[ "$platform" == "Darwin" ]
}

command_exists() {
	local command="$1"
	type "$command" >/dev/null 2>&1
}

# returns prefix key, e.g. 'C-a'
prefix() {
	tmux show-option -gv prefix
}

# if prefix is 'C-a', this function returns 'a'
prefix_without_ctrl() {
	local prefix="$(prefix)"
	echo "$prefix" | cut -d '-' -f2
}

option_value_not_changed() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gv "$option")
	[ "$option_value" == "$default_value" ]
}

server_option_value_not_changed() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -sv "$option")
	[ "$option_value" == "$default_value" ]
}

key_binding_not_set() {
	local key="$1"
	if $(tmux list-keys | grep -q "bind-key[[:space:]]\+${key}"); then
		return 1
	else
		return 0
	fi
}

key_binding_not_changed() {
	local key="$1"
	local default_value="$2"
	if $(tmux list-keys | grep -q "bind-key[[:space:]]\+${key}[[:space:]]\+${default_value}"); then
		# key still has the default binding
		return 0
	else
		return 1
	fi
}

almost_sensible_on() {
	[ "$(tmux show-option -gvq "$ALMOST_SENSIBLE_OPTION")" == "on" ]
}

main() {
	# OPTIONS

	# enable utf8
	tmux set-option -g utf8 on

	# enable utf8 in tmux status-left and status-right
	tmux set-option -g status-utf8 on

	# address vim mode switching delay (http://superuser.com/a/252717/65504)
	if server_option_value_not_changed "escape-time" "500"; then
		tmux set-option -s escape-time 0
	fi

	# increase scrollback buffer size
	if option_value_not_changed "history-limit" "2000"; then
		tmux set-option -g history-limit 50000
	fi

	# tmux messages are displayed for 4 seconds
	if option_value_not_changed "display-time" "750"; then
		tmux set-option -g display-time 4000
	fi

	# refresh 'status-left' and 'status-right' more often
	if option_value_not_changed "status-interval" "15"; then
		tmux set-option -g status-interval 5
	fi

	# required (only) on OS X
	if is_osx && command_exists "reattach-to-user-namespace" && option_value_not_changed "default-command" ""; then
		tmux set-option -g default-command "reattach-to-user-namespace -l $SHELL"
	fi

	# upgrade $TERM
	if option_value_not_changed "default-terminal" "screen"; then
		tmux set-option -g default-terminal "screen-256color"
	fi

	# emacs key bindings in tmux command prompt (prefix + :) are better than
	# vi keys, even for vim users
	tmux set-option -g status-keys emacs

	# ALMOST SENSIBLE OPTIONS

	if almost_sensible_on; then
		# C-a should be the Tmux default prefix, really
		tmux set-option -g prefix C-a
		tmux set-option -g mode-keys vi

		# enable mouse features for terminals that support it
		tmux set-option -g mouse-resize-pane on
		tmux set-option -g mouse-select-pane on
		tmux set-option -g mouse-select-window on
	fi

	# DEFAULT KEY BINDINGS

	local prefix="$(prefix)"
	local prefix_without_ctrl="$(prefix_without_ctrl)"

	# if C-b is not prefix
	if [ $prefix != "C-b" ]; then
		# unbind obsolte default binding
		if key_binding_not_changed "C-b" "send-prefix"; then
			tmux unbind-key C-b
		fi

		# pressing `prefix + prefix` sends <prefix> to the shell
		if key_binding_not_set "$prefix"; then
			tmux bind-key "$prefix" send-prefix
		fi
	fi

	# If Ctrl-a is prefix then `Ctrl-a + a` switches between alternate windows.
	# Works for any prefix character.
	if key_binding_not_set "$prefix_without_ctrl"; then
		tmux bind-key "$prefix_without_ctrl" last-window
	fi

	# easier switching between next/prev window
	if key_binding_not_set "C-p"; then
		tmux bind-key C-p previous-window
	fi
	if key_binding_not_set "C-n"; then
		tmux bind-key C-n next-window
	fi

	# source `.tmux.conf` file - as suggested in `man tmux`
	if key_binding_not_set "R"; then
		tmux bind-key R run-shell -b ' \
			tmux source-file ~/.tmux.conf > /dev/null; \
			tmux display-message "Sourced .tmux.conf!"'
	fi
}
main
