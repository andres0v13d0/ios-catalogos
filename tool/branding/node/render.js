#!/usr/bin/env node
// Rasteriza un SVG a PNG escalando por ancho O alto (preserva aspect ratio
// del viewBox) -- siempre renderiza el vector de nuevo, nunca redimensiona
// un PNG existente. El llamador (Python) hace el resto del layout
// (centrar sobre un lienzo, agregar fondo solido, etc).
// Uso: node render.js <svg_path> <out_path> --width N | --height N [--background '#RRGGBB']
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');

const args = process.argv.slice(2);
const svgPath = args[0];
const outPath = args[1];
let width = null, height = null, background = null;
for (let i = 2; i < args.length; i++) {
  if (args[i] === '--width') width = parseInt(args[++i], 10);
  else if (args[i] === '--height') height = parseInt(args[++i], 10);
  else if (args[i] === '--background') background = args[++i];
}
if (!svgPath || !outPath || (!width && !height)) {
  console.error("Uso: node render.js <svg> <out.png> --width N | --height N [--background '#RRGGBB']");
  process.exit(1);
}

const svg = fs.readFileSync(svgPath);
const opts = { fitTo: width ? { mode: 'width', value: width } : { mode: 'height', value: height } };
if (background) opts.background = background;

const resvg = new Resvg(svg, opts);
const rendered = resvg.render();
fs.writeFileSync(outPath, rendered.asPng());
console.log(`${outPath} ${rendered.width}x${rendered.height}`);
