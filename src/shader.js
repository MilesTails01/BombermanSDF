import vs from './VS.glsl?raw';
import fs from './FS.glsl?raw';

const	aspectRatio		= 1;
const	canvas 			= document.getElementById('webgl-canvas');
		canvas.width 	= 800;
		canvas.height 	= 800;
const 	gl 				= canvas.getContext('webgl2');

function createShader(gl, type, source) 
{
	const shader = gl.createShader(type);
	gl.shaderSource(shader, source);
	gl.compileShader(shader);
	if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) 
	{
		console.error(`An error occurred compiling the shader: ${gl.getShaderInfoLog(shader)}`);
		gl.deleteShader(shader);
		return null;
	}
	return shader;
}

const vertexShader 		= createShader(gl, gl.VERTEX_SHADER, vs);
const fragmentShader 	= createShader(gl, gl.FRAGMENT_SHADER, fs);
const program 			= gl.createProgram();
gl.attachShader(program, vertexShader);
gl.attachShader(program, fragmentShader);
gl.linkProgram(program);

const vertices 			= new Float32Array([-1.0, -1.0, 1.0, -1.0, 1.0, 1.0,-1.0, -1.0, 1.0, 1.0, -1.0, 1.0]);
const vertexBuffer 		= gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

const positionAttribute = gl.getAttribLocation(program, 'a_position');
gl.enableVertexAttribArray(positionAttribute);
gl.vertexAttribPointer(positionAttribute, 2, gl.FLOAT, false, 0, 0);

const timeLocation 		= gl.getUniformLocation(program, 'time');
const aspectLocation	= gl.getUniformLocation(program, "aspectRatio");
let time 				= 0;
let lastNow 			= 0;

export function renderLoop(now)
{
	time += now - lastNow;
	// now 			= now * 0.001;
	gl.clearColor(1.0, 0.5, 0.7, 1.0);
	gl.clear(gl.COLOR_BUFFER_BIT);
	gl.useProgram(program);
	gl.uniform1f(timeLocation, now * 0.001);
	// gl.uniform1f(timeLocation, now * 0.001);
	gl.drawArrays(gl.TRIANGLES, 0, vertices.length / 2);

	lastNow = now;
    requestAnimationFrame(renderLoop)
}

requestAnimationFrame(renderLoop);



function resizeCanvas()
{
	const width		= document.documentElement.clientWidth;
	const height	= document.documentElement.clientHeight;
	canvas.width	= width;
	canvas.height	= height;
	const aspect	= width / height;
	gl.viewport(0, 0, width, height);
    gl.useProgram(program);
    gl.uniform1f(aspectLocation, aspect);
}

window.addEventListener('resize', resizeCanvas);
resizeCanvas();