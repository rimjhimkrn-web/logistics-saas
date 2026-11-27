/* KRIM Global Language Persistence — shared across full-page navigation.
   Machine translation is a convenience layer, not professionally reviewed copy. */
(function(w,d){
'use strict';
if(w.KRIM_LANGUAGE_BOOTSTRAPPED)return;w.KRIM_LANGUAGE_BOOTSTRAPPED=true;
const KEY='krim-language',RTL=new Set(['ar','ur']);
const LANGS=[['en','English'],['ar','العربية'],['bn','বাংলা'],['de','Deutsch'],['es','Español'],['fr','Français'],['hi','हिन्दी'],['id','Bahasa Indonesia'],['it','Italiano'],['ja','日本語'],['pt','Português'],['ru','Русский'],['zh-CN','简体中文'],['tr','Türkçe'],['ur','اردو']];
const supported=new Set(LANGS.map(x=>x[0]));let selected=normalize(localStorage.getItem(KEY)||'en');
function normalize(v){return supported.has(v)?v:'en';}
function cookie(v){try{d.cookie='googtrans=/en/'+v+';path=/;SameSite=Lax';}catch(_){}}
function docLang(v){d.documentElement.lang=v;d.documentElement.dir=RTL.has(v.split('-')[0])?'rtl':'ltr';}
function note(t){const n=d.getElementById('krim-language-note');if(n)n.textContent=t;}
function apply(v,attempt=0){docLang(v);cookie(v);const combo=d.querySelector('.goog-te-combo');if(!combo){if(attempt<35)setTimeout(()=>apply(v,attempt+1),300);return false;}combo.value=v==='en'?'':v;combo.dispatchEvent(new Event('change'));return true;}
async function saveAccount(v){
 const client=w.KRIM_SUPABASE||w.supabaseClient;if(!client?.auth||!client.from)return;
 try{const {data:auth,error}=await client.auth.getSession();const user=auth?.session?.user;if(error||!user)return;
  const {data,error:readError}=await client.from('krim_user_app_preferences').select('preferences').eq('user_id',user.id).maybeSingle();if(readError)throw readError;
  const prefs={...(data?.preferences||{})};prefs.customer_localization={...(prefs.customer_localization||{}),language_code:v};
  const {error:writeError}=await client.from('krim_user_app_preferences').upsert({user_id:user.id,preferences:prefs,updated_at:new Date().toISOString()},{onConflict:'user_id'});if(writeError)throw writeError;
 }catch(e){console.warn('[KRIM language] Account preference save failed',e);note('Saved on this device; account sync unavailable');}
}
function choose(v,persist=true){selected=normalize(v);localStorage.setItem(KEY,selected);docLang(selected);cookie(selected);apply(selected);const s=d.getElementById('krim-language-select');if(s)s.value=selected;const pageSelect=d.getElementById('language');if(pageSelect)pageSelect.value=selected;if(persist)saveAccount(selected);note(selected==='en'?'English selected':'Applying machine translation…');d.dispatchEvent(new CustomEvent('krim:language-changed',{detail:{language:selected}}));}
async function loadAccount(){
 const client=w.KRIM_SUPABASE||w.supabaseClient;if(!client?.auth||!client.from)return;
 try{const {data:auth,error}=await client.auth.getSession();const user=auth?.session?.user;if(error||!user)return;
  const {data,error:readError}=await client.from('krim_user_app_preferences').select('preferences').eq('user_id',user.id).maybeSingle();if(readError)throw readError;
  const v=data?.preferences?.customer_localization?.language_code;if(typeof v==='string'&&supported.has(v)){selected=v;localStorage.setItem(KEY,v);const s=d.getElementById('krim-language-select');if(s)s.value=v;const pageSelect=d.getElementById('language');if(pageSelect)pageSelect.value=v;apply(v);}
 }catch(e){console.warn('[KRIM language] Account preference unavailable; using device preference',e);}
}
function mount(){
 if(d.getElementById('krim-language-control'))return;
 const mobile=w.matchMedia('(max-width:960px)').matches;
 const host=d.querySelector('header .nav-actions')||(mobile?d.querySelector('header #primary-nav,header .nav-links,header nav'):d.querySelector('header #primary-nav,header nav'))||d.body;
 const box=d.createElement('div');box.id='krim-language-control';
 box.innerHTML='<button type="button" id="krim-language-toggle" aria-label="Select language" aria-expanded="false" title="Language"><span aria-hidden="true">◎</span><span class="krim-language-word">Language</span></button><div id="krim-language-menu" hidden><label for="krim-language-select">Preferred language</label><select id="krim-language-select" aria-label="Choose preferred language">'+LANGS.map(([v,n])=>'<option value="'+v+'">'+n+'</option>').join('')+'</select><span id="krim-language-note" role="status" aria-live="polite"></span></div>';
 const css=d.createElement('style');css.textContent='#krim-language-control{position:relative;display:inline-flex;align-items:center;flex:0 0 auto;margin:0 8px;z-index:9999;font:600 13px system-ui}#krim-language-toggle{min-height:40px;display:flex;align-items:center;gap:8px;padding:0 12px;border:1px solid #0754A4;border-radius:10px;background:#0754A4;color:#fff;font-size:14px;cursor:pointer}#krim-language-menu{position:absolute;right:0;top:calc(100% + 8px);display:flex;flex-direction:column;gap:7px;min-width:190px;padding:12px;background:#fff;color:#164B78;border:1px solid #45B8F0;border-radius:12px;box-shadow:0 10px 30px #165b8c26}#krim-language-menu[hidden]{display:none}#krim-language-menu select{width:100%;min-height:42px;padding:7px 9px;border:1px solid #45B8F0;border-radius:8px;background:#F2F9FE;color:#164B78;font:600 14px system-ui}#krim-language-note{font-size:11px;color:#168FE0}#google_translate_element{position:absolute!important;width:1px!important;height:1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important}.goog-te-banner-frame{display:none!important}body{top:0!important}@media(max-width:960px){header .nav-actions #krim-language-control{width:auto;display:inline-flex;margin:0}#krim-language-control{width:100%;display:flex;justify-content:flex-start;padding:10px 4px 4px;border-top:1px solid #edf1f5;margin:8px 0 0}#krim-language-menu{left:4px;right:auto;min-width:min(240px,calc(100vw - 48px))}}@media(min-width:961px){header .nav-actions #krim-language-control{margin:0 2px}body>#krim-language-control{position:fixed;right:18px;bottom:18px;margin:0}}';
 d.head.appendChild(css);host.appendChild(box);const hidden=d.createElement('div');hidden.id='google_translate_element';d.body.appendChild(hidden);
 const toggle=box.querySelector('#krim-language-toggle'),menu=box.querySelector('#krim-language-menu'),sel=box.querySelector('select');sel.value=selected;
 toggle.addEventListener('click',()=>{const open=menu.hidden;menu.hidden=!open;toggle.setAttribute('aria-expanded',String(open));if(open)sel.focus();});
 d.addEventListener('click',e=>{if(!box.contains(e.target)){menu.hidden=true;toggle.setAttribute('aria-expanded','false');}});
 sel.addEventListener('change',()=>choose(sel.value,true));
 const pageSelect=d.getElementById('language');if(pageSelect){pageSelect.addEventListener('change',()=>choose(pageSelect.value,true));}
 w.krimGoogleTranslateReady=function(){if(!w.google?.translate?.TranslateElement)return;new w.google.translate.TranslateElement({pageLanguage:'en',includedLanguages:LANGS.map(x=>x[0]).filter(x=>x!=='en').join(','),autoDisplay:false},'google_translate_element');apply(selected);};
 const script=d.createElement('script');script.src='https://translate.google.com/translate_a/element.js?cb=krimGoogleTranslateReady';script.async=true;script.onerror=()=>note('Translation service unavailable on this page');d.head.appendChild(script);
}
async function start(){docLang(selected);cookie(selected);mount();await loadAccount();const client=w.KRIM_SUPABASE||w.supabaseClient;if(client?.auth?.onAuthStateChange)client.auth.onAuthStateChange((event)=>{if(event==='SIGNED_IN')setTimeout(()=>loadAccount(),0);});const s=d.getElementById('krim-language-select');if(s)s.value=selected;const pageSelect=d.getElementById('language');if(pageSelect)pageSelect.value=selected;apply(selected);}
if(d.readyState==='loading')d.addEventListener('DOMContentLoaded',start,{once:true});else start();
w.addEventListener('storage',e=>{if(e.key===KEY&&e.newValue){selected=normalize(e.newValue);const s=d.getElementById('krim-language-select');if(s)s.value=selected;const pageSelect=d.getElementById('language');if(pageSelect)pageSelect.value=selected;apply(selected);}});
w.KRIM_LANGUAGE={get current(){return selected;},set:choose,languages:LANGS.map(x=>({code:x[0],name:x[1]}))};
})(window,document);
