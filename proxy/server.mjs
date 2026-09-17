import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';

export function createProxy({apiKey, modelId, supportedPpe, tokens, fetchImpl = fetch}) {
  if (!apiKey || !/^[a-zA-Z0-9_-]+\/\d+$/.test(modelId || '') || !tokens?.length || tokens.some(t => t.length < 24)) throw new Error('Configure model, server API key, and access tokens of at least 24 characters.');
  const allowed = new Set(['helmet','vest','gloves','goggles','mask']);
  if (!supportedPpe?.length || supportedPpe.some(t=>!allowed.has(t))) throw new Error('Set verified SUPPORTED_PPE classes.');
  const limits = new Map();
  let inflight = 0;
  const send = (res,status,body) => {res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(body));};
  return http.createServer(async (req,res) => {
    if(req.method==='GET'&&req.url==='/health') return send(res,200,{status:'ok'});
    if(req.method!=='POST'||req.url!=='/infer') return send(res,404,{error:'Not found'});
    const token=(req.headers.authorization||'').replace(/^Bearer /,'');
    const valid=tokens.some(t=>Buffer.byteLength(t)===Buffer.byteLength(token)&&timingSafeEqual(Buffer.from(t),Buffer.from(token)));
    if(!valid) return send(res,401,{error:'Unauthorized'});
    const now=Date.now();
    const bucket=limits.get(token)||{time:now,count:0};
    if(now-bucket.time>=60000){bucket.time=now;bucket.count=0;}
    bucket.count++;limits.set(token,bucket);
    if(bucket.count>180||inflight>=8) return send(res,429,{error:'Retry later'});
    if(!String(req.headers['content-type']).startsWith('application/json')) return send(res,415,{error:'JSON required'});
    let size=0;const chunks=[];
    try {
      for await (const chunk of req) {size+=chunk.length;if(size>3*1024*1024){send(res,413,{error:'Image too large'});req.resume();return;}chunks.push(chunk);}
      const body=JSON.parse(Buffer.concat(chunks).toString());
      if(typeof body.image!=='string'||body.image.length<8||!/^[A-Za-z0-9+/]+={0,2}$/.test(body.image)) return send(res,400,{error:'A base64 JPEG image is required'});
      const bytes=Buffer.from(body.image,'base64');
      if(bytes[0]!==255||bytes[1]!==216) return send(res,400,{error:'JPEG required'});
      const threshold=body.confidence??.6;
      if(typeof threshold!=='number'||!Number.isFinite(threshold)||threshold<.3||threshold>.95) return send(res,400,{error:'Invalid confidence threshold'});
      const url=new URL(`https://detect.roboflow.com/${modelId}`);
      url.searchParams.set('api_key',apiKey);url.searchParams.set('confidence',String(Math.round(threshold*100)));
      inflight++;
      try {
        const response=await fetchImpl(url,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:body.image,signal:AbortSignal.timeout(10000)});
        if(!response.ok) return send(res,502,{error:'Inference provider unavailable'});
        const result=await response.json();
        if(!Array.isArray(result.predictions)||!result.image?.width||!result.image?.height) return send(res,502,{error:'Invalid provider response'});
        // Never log/store images, authentication tokens, or provider URLs containing the key.
        send(res,200,{predictions:result.predictions,image:result.image,supported_ppe:supportedPpe});
      } finally {inflight--;}
    } catch(error) {if(!res.headersSent) send(res,error instanceof SyntaxError?400:502,{error:error instanceof SyntaxError?'Invalid JSON':'Inference unavailable'});}
  });
}
if (process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  const server=createProxy({apiKey:process.env.ROBOFLOW_API_KEY,modelId:process.env.ROBOFLOW_MODEL_ID,supportedPpe:process.env.SUPPORTED_PPE?.split(',').map(s=>s.trim()).filter(Boolean),tokens:process.env.PROXY_TOKENS?.split(',').map(s=>s.trim()).filter(Boolean)});
  server.requestTimeout=15000;server.headersTimeout=10000;
  server.listen(Number(process.env.PORT||8080),'0.0.0.0',()=>process.stdout.write('SafetyLens inference proxy started\n'));
}
