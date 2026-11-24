import {$,read,save} from './ui.js';
const canvas=$('#preview'), editor=$('#source');
const example=`precision mediump float;
uniform vec2 resolution;
uniform float time;
void main() {
  vec2 p = gl_FragCoord.xy / resolution;
  float bend = 0.16 * sin(5.2 * p.x + time * 0.35);
  float fold = fract(5.0 * (p.y + bend + 0.32 * p.x));
  vec3 ink = vec3(0.21, 0.10, 0.34);
  vec3 iris = vec3(0.76, 0.46, 0.90);
  vec3 peach = vec3(1.0, 0.72, 0.56);
  vec3 color = mix(ink, iris, smoothstep(0.04, 0.88, fold));
  gl_FragColor = vec4(mix(color, peach, smoothstep(0.86, 1.0, fold)), 1.0);
}`;
editor.value=read('chromafold-source',example);
const gl=canvas.getContext('webgl');
let active,position,clock,size,buffer,seconds=0,last=0;
let running=!matchMedia('(prefers-reduced-motion: reduce)').matches;
function shader(type,source){
  const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);
  if(gl.getShaderParameter(s,gl.COMPILE_STATUS))return s;
  const log=gl.getShaderInfoLog(s);gl.deleteShader(s);throw Error(log);
}
function compile(){
  const parts=[];let program;
  try{
    parts.push(shader(gl.VERTEX_SHADER,'attribute vec2 p; void main(){gl_Position=vec4(p,0.,1.);}'));
    parts.push(shader(gl.FRAGMENT_SHADER,editor.value));
    program=gl.createProgram();for(const s of parts)gl.attachShader(program,s);gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));
    gl.useProgram(program);if(active)gl.deleteProgram(active);active=program;
    position=gl.getAttribLocation(active,'p');size=gl.getUniformLocation(active,'resolution');clock=gl.getUniformLocation(active,'time');
    gl.enableVertexAttribArray(position);gl.vertexAttribPointer(position,2,gl.FLOAT,false,0,0);
    save('chromafold-source',editor.value);$('#log').textContent='';$('#status').textContent='Compiled';draw();
  }catch(error){if(program!==active && program)gl.deleteProgram(program);$('#log').textContent=error.message;$('#status').textContent='Compile error'}
  finally{for(const s of parts)gl.deleteShader(s)}
}
function draw(){if(!active)return;const w=Math.round(canvas.clientWidth),h=Math.round(canvas.clientHeight);if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h}gl.viewport(0,0,w,h);gl.uniform2f(size,w,h);gl.uniform1f(clock,seconds);gl.drawArrays(gl.TRIANGLES,0,3)}
function frame(now){if(running&&last)seconds+=Math.min((now-last)/1000,.1);last=now;if(running)draw();requestAnimationFrame(frame)}
$('#pause').textContent=running?'Pause':'Play';
if(gl){buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);$('#run').onclick=compile;$('#pause').onclick=()=>{running=!running;$('#pause').textContent=running?'Pause':'Play'};new ResizeObserver(draw).observe(canvas);compile();requestAnimationFrame(frame)}
else{$('#status').textContent='WebGL unavailable on this device.';$('#run').disabled=$('#pause').disabled=true}
