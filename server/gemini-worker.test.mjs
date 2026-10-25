import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './gemini-worker.mjs';
const token='synthetic-test-token-only';
const env={LIFEOS_GATEWAY_TOKEN:token,GEMINI_API_KEY:'synthetic-test-key-only',GEMINI_FREE_PROJECT_CONFIRMED:'true',LIFEOS_AI_MODEL:'test-flash-model'};
function request(path='/v1/chat',body={message:'Explain a queue'}) {
 return new Request(`https://gateway.example${path}`,{method:path==='/health'?'GET':'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:path==='/health'?undefined:JSON.stringify(body)});
}
test('missing authentication never reaches a provider',async()=>{
 const result=await worker.fetch(new Request('https://gateway.example/v1/chat',{method:'POST'}),env);
 assert.equal(result.status,401);
});
test('provider stays disabled without an explicit free-project confirmation',async()=>{
 const result=await worker.fetch(request('/health'),{...env,GEMINI_FREE_PROJECT_CONFIRMED:'false'});
 assert.equal((await result.json()).ready,false);
 const chat=await worker.fetch(request(),{...env,GEMINI_FREE_PROJECT_CONFIRMED:'false'});
 assert.equal(chat.status,503);
});
test('only explicit prompt/source are sent, with keys kept in server headers',async()=>{
 const original=globalThis.fetch;
 globalThis.fetch=async(url,options)=>{
  assert.match(url,/models\/test-flash-model:generateContent$/);
  assert.equal(options.headers['x-goog-api-key'],'synthetic-test-key-only');
  const body=JSON.parse(options.body);
  assert.match(body.contents[0].parts[0].text,/Explain a queue/);
  assert.match(body.contents[0].parts[0].text,/UNTRUSTED/);
  return Response.json({candidates:[{content:{parts:[{text:'A queue is FIFO.'}]}}]});
 };
 try{
  const result=await worker.fetch(request('/v1/chat',{message:'Explain a queue',source:'My source passage'}),env);
  const data=await result.json();assert.equal(data.text,'A queue is FIFO.');assert.equal(data.live,true);
  assert.equal(JSON.stringify(data).includes('synthetic-test-key-only'),false);
 }finally{globalThis.fetch=original;}
});
test('quota errors stop without falling back to another provider',async()=>{
 const original=globalThis.fetch;let calls=0;
 globalThis.fetch=async()=>{calls++;return new Response('{}',{status:429});};
 try{assert.equal((await worker.fetch(request(),env)).status,429);assert.equal(calls,1);}finally{globalThis.fetch=original;}
});
test('oversized request body is rejected before contacting Gemini',async()=>{
 const original=globalThis.fetch;let calls=0;
 globalThis.fetch=async()=>{calls++;throw new Error('must not contact provider');};
 try {assert.equal((await worker.fetch(request('/v1/chat',{message:'x'.repeat(40000)}),env)).status,413);assert.equal(calls,0);} finally {globalThis.fetch=original;}
});
test('an unrelated browser origin is rejected even with a valid token',async()=>{
 const input=request();input.headers.set('Origin','https://unrelated.example');
 assert.equal((await worker.fetch(input,env)).status,403);
});
