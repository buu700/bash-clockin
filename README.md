# bash-clockin

## Overview

I recently took on some contract work and needed an easy way to track my billable hours.
Didn't feel like bothering to evaluate what other solutions were out there so I just took
a few minutes and threw together a few quick and dirty shell commands.

This works well for my workflow (I spend a good portion of the day working out of a Quake-style
terminal that I always have open), but I don't necessarily expect it to meet everyone's needs
as-is. Maybe someone with some free time will fork it and polish it up.

## Usage

To start, pick a name for your contract (or whatever you're tracking hours for) and run:

	./bash-clockin.sh <contract_name>

For the sake of example let's say we're calling it "cyph":

	./bash-clockin.sh cyph

Now you have the following commands included in your bashrc:

	cyphstartwork [task_summary] # Clocks in

	cyphstopwork # Clocks out

	cyphprintlog [last_bill_date] # Prints CSV-formatted log of work

Example usage:

	$ cyphprintlog
	Date,Hours,Tasks
	2/11/2019,6,robotic armor firmware development; tech requirements review call
	2/12/2019,8.5,call with Barack; robotic armor firmware development
	2/13/2019,9,build/release call; HUD development; call with Josh; robotic armor firmware development; sprint planning call; standup
	2/14/2019,10.5,Docker image setup; call with Barack; standup
	2/15/2019,8,HUD development; call with Barack; design review call; standup
	Total,42

	$ cyphstartwork mugging a senior citizen

	$ cyphstopwork

	$ cyphprintlog 2019-02-13
	Date,Hours,Tasks
	2/14/2019,10.5,Docker image setup; call with Barack; standup
	2/15/2019,8,HUD development; call with Barack; design review call; standup
	2/17/2019,0.5,mugging a senior citizen
	Total,18.5

## Dependencies

* Bash

* Node.js 8+

* Write access to ~/.bashrc, `~/.${name}.inc`, and `~/${name}.log`

(In my case `${name}.log` is symlinked to a file in Google Drive.)
