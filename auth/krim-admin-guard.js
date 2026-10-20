(function(){
"use strict";
const URL="https://ebltviniygljwwseplph.supabase.co";
const KEY="sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";
const parts=location.pathname.split("/").filter(Boolean);
const base=location.hostname.endsWith("github.io")?"/"+(parts[0]||"logistics-saas"):"";
const gate=base+"/auth/krim-admin-access.html?reason=required";
function deny(){location.replace(gate)}
async function loadSdk(){
 if(window.supabase)return;
 await new Promise((resolve,reject)=>{const s=document.createElement("script");s.src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";s.onload=resolve;s.onerror=reject;document.head.appendChild(s)});
}
(async()=>{
 try{
  await loadSdk();
  if(!window.supabase)throw new Error("Auth SDK unavailable");
  const client=window.supabase.createClient(URL,KEY);
  const {data,error}=await client.auth.getSession();
  if(error||!data.session){deny();return}
  const {data:result,error:invokeError}=await client.functions.invoke("global-admin-control",{body:{action:"overview"}});
  if(invokeError||!result||result.ok!==true){deny();return}
  document.documentElement.classList.add("krim-admin-authorized");
 }catch(_){deny()}
})();
})();