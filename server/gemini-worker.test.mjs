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
test('provider HTTP failures preserve safe categories without echoing secrets or prompts',async()=>{
 const original=globalThis.fetch;
 try {
  for(const [status,reason,code] of [[400,'API_KEY_INVALID','gemini_key'],[401,null,'gemini_key'],[403,'SERVICE_DISABLED','gemini_permission'],[404,null,'gemini_model'],[400,null,'gemini_request'],[429,null,'gemini_quota'],[503,null,'gemini_unavailable']]) {
   let calls=0;
   globalThis.fetch=async()=>{calls++;return Response.json({error:{message:'synthetic-test-key-only PRIVATE PROMPT',details:[{reason,metadata:{key:'synthetic-test-key-only'}}]}},{status});};
   const result=await worker.fetch(request(),env), data=await result.json();
   assert.equal(result.status,status===429?429:502);assert.equal(data.code,code);assert.equal(data.upstreamStatus,status);assert.equal(calls,1);
   assert.equal(JSON.stringify(data).includes('synthetic-test-key-only'),false);assert.equal(JSON.stringify(data).includes('PRIVATE PROMPT'),false);
  }
 } finally {globalThis.fetch=original;}
});
test('blocked, output-limited, empty and unreadable replies are distinguished',async()=>{
 const original=globalThis.fetch;
 try {
  for(const [body,code] of [[{promptFeedback:{blockReason:'SAFETY'}},'gemini_blocked'],[{candidates:[{finishReason:'MAX_TOKENS',content:{parts:[{text:'partial'}]}}]},'gemini_output_limit'],[{candidates:[]},'gemini_empty']]) {
   globalThis.fetch=async()=>Response.json(body);
   const result=await worker.fetch(request(),env);assert.equal(result.status,502);assert.equal((await result.json()).code,code);
  }
  globalThis.fetch=async()=>new Response('<html>private upstream error</html>');
  assert.equal((await (await worker.fetch(request(),env)).json()).code,'gemini_invalid_response');
  globalThis.fetch=async()=>new Response('<html>private upstream error</html>',{status:503});
  assert.equal((await (await worker.fetch(request(),env)).json()).upstreamStatus,503);
 } finally {globalThis.fetch=original;}
});
test('only final answer parts are returned',async()=>{
 const original=globalThis.fetch;
 globalThis.fetch=async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{thought:true,text:'Excluded model thought'},{text:'{"answer":"A brief answer","proposal":null}'}]}}]});
 try {const data=await (await worker.fetch(request(),env)).json();assert.equal(data.text,'A brief answer');assert.equal(JSON.stringify(data).includes('Excluded model thought'),false);} finally {globalThis.fetch=original;}
});
test('transport timeouts and network exceptions do not expose raw exception text',async()=>{
 const original=globalThis.fetch;
 try {
  for(const name of ['TimeoutError','TypeError']) {
   globalThis.fetch=async()=>{const e=new Error('synthetic-test-key-only');e.name=name;throw e;};
   const response=await worker.fetch(request(),env),data=await response.json();
   assert.equal(data.code,name==='TimeoutError'?'gateway_timeout':'gateway_network');assert.equal(JSON.stringify(data).includes('synthetic-test-key-only'),false);
  }
 } finally {globalThis.fetch=original;}
});
test('bad JSON and null bodies are request errors and never contact Gemini',async()=>{
 const original=globalThis.fetch;let calls=0;globalThis.fetch=async()=>{calls++;throw new Error('Unexpected generation');};
 try {
  for(const body of ['null','{broken']) {
   const input=new Request('https://gateway.example/v1/chat',{method:'POST',headers:{Authorization:`Bearer ${token}`},body});
   const result=await worker.fetch(input,env);assert.equal(result.status,400);assert.equal((await result.json()).code,'invalid_request');
  }
  assert.equal(calls,0);
 } finally {globalThis.fetch=original;}
});
test('HTTP400 key and account errors expose only allowlisted RPC categories',async()=>{
 const original=globalThis.fetch;
 try {
  for(const [message,status,code] of [
   ['API key not valid. PRIVATE KEY','INVALID_ARGUMENT','gemini_key'],
   ['API key was reported as leaked. PRIVATE KEY','INVALID_ARGUMENT','gemini_key'],
   ['PRIVATE REGION / ACCOUNT','FAILED_PRECONDITION','gemini_precondition'],
   ['PRIVATE REQUEST','INVALID_ARGUMENT','gemini_request'],
   ['PRIVATE REQUEST','PRIVATE KEY','gemini_request'],
  ]) {
   globalThis.fetch=async()=>Response.json({error:{message,status}},{status:400});
   const data=await (await worker.fetch(request(),env)).json();
   assert.equal(data.code,code);assert.equal(data.upstreamStatus,400);
   assert.equal(data.rpcStatus,status==='PRIVATE KEY'?undefined:status);
   assert.equal(JSON.stringify(data).includes('PRIVATE'),false);
  }
 } finally {globalThis.fetch=original;}
});
