name="${1}"

if [ ! "${name}" ] ; then
	echo 'Usage: ./bash-clockin.sh <contract_name>'
	exit 1
fi


set -e

touch ~/${name}.log

cat > ~/.${name}.inc << EOM

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

_${name}getlist () {
	echo "
		/* https://stackoverflow.com/a/11888430/459881 */
		const timezoneOffset = (() => {
			const d = new Date();
			const jan = new Date(d.getFullYear(), 0, 1);
			const jul = new Date(d.getFullYear(), 6, 1);

			const offset = d.getTimezoneOffset();
			const stdOffset = Math.max(jan.getTimezoneOffset(), jul.getTimezoneOffset());

			return offset + (offset < stdOffset ? 60 : 0);
		})();

		const getList = (afterDate, beforeDate) => [
			...fs.readFileSync(
				path.join(os.homedir(), '${name}.log')
			).toString().trim().split('\n'),
			'\$(date): STOP'
		].map(s => {
			const dateTimeString = s.
				replace(/: (START|STOP).*/, '').
				replace(/ A([SD])T /, (_, c) => \\\` E\\\${c}T \\\`)
			;

			return {
				date: new Date(dateTimeString),
				dateTimeString,
				originalDate: new Date(dateTimeString.replace(/(\d+:?)+ [A-Z]+ /, '')),
				start: s.indexOf(': START: ') > -1,
				task: s.split(': START: ')[1]
			};
		}).filter(({originalDate}) =>
			originalDate > afterDate &&
			originalDate < beforeDate
		);
	"
}

${name}printlog () {
	node -e "
		\$(_${name}getlist)

		const list = getList(
			new Date(
				new Date('\${1}' || 0).getTime() +
				timezoneOffset * 60000
			),
			new Date()
		);

		const dates = list.reduce(
			(acc, o) => {
				const dateString = o.originalDate.toLocaleDateString();

				if (!acc[dateString]) {
					const yesterday =
						new Date(o.originalDate.getTime() - 86400000).toLocaleDateString()
					;

					const lastEvent =
						acc[yesterday] &&
						acc[yesterday].slice(-1)[0]
					;

					if (lastEvent && lastEvent.start) {
						const yesterdayDateTimeString =
							lastEvent.dateTimeString.replace(/\d+:\d+:\d+/, '23:59:59')
						;

						const todayDateTimeString =
							o.dateTimeString.replace(/\d+:\d+:\d+/, '00:00:00')
						;

						acc[yesterday].push({
							...lastEvent,
							date: new Date(yesterdayDateTimeString),
							dateTimeString: yesterdayDateTimeString,
							start: false,
							task: undefined
						});

						acc[dateString] = [{
							...lastEvent,
							date: new Date(todayDateTimeString),
							dateTimeString: todayDateTimeString
						}];
					}
				}

				return {
					...acc,
					[dateString]: [...(acc[dateString] || []), o]
				}
			},
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
					data.time === 0 ? 0 : Math.max(Math.round(data.time / 1800000) / 2, 0.5),
					Array.from(new Set(data.tasks.filter(s => s))).sort().join('; ')
				];
			})
		];

		console.log([
			...table,
			['Total', table.slice(1).reduce((total, [_, n]) => total + n, 0)]
		].
			filter(arr => arr[1] !== 0).
			map(arr => arr.join(',')).
			join('\n')
		);
	"
}

${name}togglsync () {
	node -e "
		const TogglClient = require('toggl-api');
		const toggl = new TogglClient({apiToken:
			fs.readFileSync(
				path.join(os.homedir(), '.${name}.toggl.key')
			).toString().trim()
		});

		const lastSyncDatePath = path.join(os.homedir(), '.${name}.toggl.lastsync');

		const pidPath = path.join(os.homedir(), '.${name}.toggl.pid');
		const pid = fs.existsSync(pidPath) ?
			parseInt(fs.readFileSync(pidPath).toString(), 10) :
			undefined
		;

		\$(_${name}getlist)

		const end = new Date();
		end.setHours(0, 0, 0, 0);

		let start = new Date(0);
		if (fs.existsSync(lastSyncDatePath)) {
			start = new Date(fs.readFileSync(lastSyncDatePath).toString());
			start.setHours(0, 0, 0, 0);
			start = new Date(start.getTime() - 86400000);
		}

		const list = getList(start, end);

		const entries = list.
			map((o, i) => !o.start ? undefined : {
				billable: true,
				description: o.task,
				duration:
					(
						(list[i + 1] || {date: end}).date.getTime() -
						o.date.getTime()
					) / 1000
				,
				pid,
				start: o.date.toISOString()
			}).
			filter(o => o)
		;

		const badEntries = entries.filter(o => !(
			!isNaN(o.duration) &&
			o.duration > 0 &&
			o.duration < 3596400
		));

		if (badEntries.length > 0) {
			console.error({badEntries});
			process.exit(0);
		}

		(async () => {
			for (const entry of entries) {
				let err;

				for (let i = 0 ; i < 5 ; ++i) {
					err = await new Promise(resolve =>
						toggl.createTimeEntry(entry, resolve)
					);

					if (!err) {
						break;
					}

					await util.promisify(setTimeout)(1000);
				}

				if (err) {
					console.error(err);
					return;
				}
			}

			fs.writeFileSync(lastSyncDatePath, end.toLocaleDateString());
			console.log('Toggl updated!');
		})();
	"
}

EOM

echo "source ~/.${name}.inc # bash-clockin" >> ~/.bashrc
