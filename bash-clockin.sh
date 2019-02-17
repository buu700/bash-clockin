name="${1}"

if [ ! "${name}" ] ; then
	echo 'Usage: ./bash-clockin.sh <contract_name>'
	exit 1
fi


set -e

touch ~/${name}.log

cat >> ~/.${name}.inc <<- EOM

${name}startwork () {
	if echo "\${*}" | grep -qP '(,|START|STOP)' ; then
		echo "String cannot contain comma, START, or STOP"
	else
		echo "\$(date): START: \${*}" >> ~/${name}.log
	fi
}

${name}stopwork () {
	echo "\$(date): STOP" >> ~/${name}.log
}

${name}printlog () {
	node -e "
		const afterDate = new Date(
			new Date('\${1}' || 0).getTime() +
			new Date().getTimezoneOffset() * 60000
		);

		const list = fs.readFileSync(
			path.join(os.homedir(), '${name}.log')
		).toString().trim().split('\n').map(s => ({
			date: new Date(s.replace(/: (START|STOP).*/, '')),
			start: s.indexOf(': START: ') > -1,
			task: s.split(': START: ')[1]
		})).filter(({date}) =>
			date.getTime() >= afterDate &&
			date.toLocaleDateString() !== afterDate.toLocaleDateString()
		);

		const dates = list.reduce(
			(acc, o) => ({
				...acc,
				[o.date.toLocaleDateString()]: [...(acc[o.date.toLocaleDateString()] || []), o]
			}),
			{}
		);

		const table = [
			['Date', 'Hours', 'Tasks'],
			...Object.keys(dates).map(k => {
				const data = [...dates[k].slice(1), {date: new Date(), start: false}].reduce(
					({last, tasks, time}, o) => last.start && o.start ?
						{last, tasks: [...tasks, o.task], time} :
						{
							last: o,
							tasks: [...tasks, o.task],
							time: last.start && !o.start ?
								time + (o.date.getTime() - last.date.getTime()) :
								time
						}
					,
					{last: dates[k][0], tasks: [dates[k][0].task], time: 0}
				);

				return [
					k,
					Math.round(data.time / 1800000) / 2,
					Array.from(new Set(data.tasks.filter(s => s))).sort().join('; ')
				];
			})
		];

		console.log([
			...table,
			['Total', table.slice(1).reduce((total, [_, n]) => total + n, 0)]
		].
			map(arr => arr.join(',')).
			join('\n')
		);
	"
}

EOM

echo "source ~/.${name}.inc # bash-clockin" >> ~/.bashrc
