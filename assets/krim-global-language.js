(()=>{"use strict";
const langs=[["en","English"],["ar","العربية"],["bn","বাংলা"],["de","Deutsch"],["es","Español"],["fr","Français"],["hi","हिन्दी"],["id","Bahasa Indonesia"],["it","Italiano"],["ja","日本語"],["pt","Português"],["ru","Русский"],["zh-CN","简体中文"],["tr","Türkçe"],["ur","اردو"]],rtl=["ar","ur"];
function boot(){
 if(document.getElementById("krim-language-control"))return;
 const mobile=matchMedia("(max-width:960px)").matches;
 const host=mobile?(document.querySelector("header #primary-nav,header .nav-links,header nav")||document.body):(document.querySelector("header .nav-actions")||document.querySelector("header #primary-nav,header nav")||document.body);
 const floating=host===document.body;
 const box=document.createElement("div");box.id="krim-language-control";box.innerHTML='<button type="button" id="krim-language-toggle" aria-label="Select language" aria-expanded="false" title="Language"><span aria-hidden="true">◎</span><span class="krim-language-word">Language</span></button><div id="krim-language-menu" hidden><label for="krim-language-select">Language</label><select id="krim-language-select" aria-label="Choose language">'+langs.map(([v,n])=>'<option value="'+v+'">'+n+'</option>').join("")+'</select><span id="krim-language-note" role="status" aria-live="polite"></span></div>';
 const css=document.createElement("style");css.textContent=`
#krim-language-control{position:relative;display:inline-flex;align-items:center;flex:0 0 auto;margin:0 8px;z-index:9999;font:600 13px system-ui}
#krim-language-toggle{min-height:40px;display:flex;align-items:center;justify-content:center;gap:8px;padding:0 12px;border:1px solid #c7d5e4;border-radius:10px;background:#071b31;color:#fff;box-shadow:0 3px 10px #071b3120;font-size:14px;line-height:1;cursor:pointer}
#krim-language-toggle:hover{background:#174b78}
#krim-language-menu{position:absolute;right:0;top:calc(100% + 8px);display:flex;flex-direction:column;gap:7px;min-width:190px;padding:12px;background:#fff;color:#10243d;border:1px solid #d7e1ec;border-radius:12px;box-shadow:0 10px 30px #071b3130}
#krim-language-menu[hidden]{display:none}
#krim-language-menu select{width:100%;min-height:42px;padding:7px 9px;border:1px solid #9fb3c8;border-radius:8px;background:#fff;color:#10243d;font:600 14px system-ui}
#krim-language-note{font-size:11px;color:#26736d}
#google_translate_element{position:absolute!important;width:1px!important;height:1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important}
.goog-te-banner-frame{display:none!important}body{top:0!important}
@media(max-width:960px){#krim-language-control{width:100%;display:flex;justify-content:flex-start;padding:10px 4px 4px;border-top:1px solid #edf1f5;margin:8px 0 0}#krim-language-toggle{min-height:44px;padding:0 14px}#krim-language-menu{left:4px;right:auto;min-width:min(240px,calc(100vw - 48px))}}
@media(min-width:961px){header .nav-actions #krim-language-control{margin:0 2px}header .nav-actions #krim-language-toggle .krim-language-word{display:inline}body>#krim-language-control{position:fixed;right:18px;bottom:18px;margin:0;padding:0}}
`;document.head.appendChild(css);host.appendChild(box);
 const hidden=document.createElement("div");hidden.id="google_translate_element";document.body.appendChild(hidden);
 const toggle=box.querySelector("#krim-language-toggle"),menu=box.querySelector("#krim-language-menu"),sel=box.querySelector("select"),note=box.querySelector("#krim-language-note"),saved=localStorage.getItem("krim-language")||"en";sel.value=saved;
 toggle.addEventListener("click",()=>{const open=menu.hidden;menu.hidden=!open;toggle.setAttribute("aria-expanded",String(open));if(open)sel.focus()});
 document.addEventListener("click",e=>{if(!box.contains(e.target)){menu.hidden=true;toggle.setAttribute("aria-expanded","false")}});
 window.googleTranslateElementInit=()=>{if(!window.google?.translate?.TranslateElement)return;new google.translate.TranslateElement({pageLanguage:"en",includedLanguages:langs.map(x=>x[0]).filter(x=>x!=="en").join(","),autoDisplay:false},"google_translate_element");if(saved!=="en")setTimeout(()=>apply(saved),1200)};
 function apply(v){const combo=document.querySelector(".goog-te-combo");if(!combo){note.textContent="Translation loading…";return}combo.value=v;combo.dispatchEvent(new Event("change"));document.documentElement.lang=v;document.documentElement.dir=rtl.includes(v)?"rtl":"ltr";note.textContent="Machine translated"}
 sel.addEventListener("change",()=>{const v=sel.value;localStorage.setItem("krim-language",v);if(v==="en"){const c=document.querySelector(".goog-te-combo");if(c){c.value="";c.dispatchEvent(new Event("change"))}document.documentElement.lang="en";document.documentElement.dir="ltr";note.textContent="";return}apply(v)});
 const s=document.createElement("script");s.src="https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";s.async=true;s.onerror=()=>note.textContent="Translation unavailable";document.head.appendChild(s);
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",boot,{once:true});else boot();
})();