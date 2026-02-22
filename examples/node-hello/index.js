export function greeting(name = 'world') {
  return `Hello, ${name}!`;
}

if (process.argv[1] && process.argv[1].endsWith('index.js')) {
  console.log(greeting());
}
