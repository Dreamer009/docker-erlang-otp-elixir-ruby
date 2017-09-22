var parser = require('docker-file-parser');
var options = { includeComments: false };
var fs = require('fs');

let envStrings = [];
let runStrings = [];

['Dockerfile-erlang', 'Dockerfile-elixir', 'Dockerfile-ruby'].forEach(filename => {
	let contents = fs.readFileSync(filename, 'utf8')
		         .replace(/^#.*\n?/gm, ""); // The Ruby Dockerfile has some comments that cause some of the commands to get cut off

	let commands = parser.parse(contents, options);
	let envCommands = commands.filter(command => command.name == 'ENV')
	let runCommands = commands.filter(command => command.name == 'RUN')

	envCommands.forEach(command => {
		for (var k in command.args) {
			envStrings.push(`export ${k}=${command.args[k]}`)
		}
	});

	runCommands.forEach(command => {
		let cmd = command.args.replace(/[\\$"]/g, "\\$&");
		runStrings.push(`bash -c "${cmd}"`);
	});
});

console.log(envStrings.join("\n"));
console.log("\n");
console.log(runStrings.join("\n\n"));
