/* KRIM global brand lockup — idempotently enforces the approved full master logo. */
(function(){
  "use strict";
  var base="/logistics-saas/assets/krim-primary.svg?v=20261111-global-brand-v1";
  function apply(){
    if(document.documentElement.dataset.krimBrandApplied==="1") return;
    document.documentElement.dataset.krimBrandApplied="1";
    var header=document.querySelector("header");
    var candidates=[
      header&&header.querySelector(".brand-mark"),
      header&&header.querySelector(".mark"),
      header&&header.querySelector(".brandmark"),
      header&&header.querySelector(".logo"),
      header&&header.querySelector('img[alt*="krim" i],img[alt*="logo" i]'),
      header&&header.querySelector('[class*="brand"] img'),
      header&&header.querySelector('[class*="logo"] img')
    ].filter(Boolean);
    var target=candidates[0]||null;
    if(!target){
      var any=document.querySelector('img[alt*="krim" i],img[alt*="logo" i],img[src*="krim-icon"],img[src*="krim-mark"],img[src*="logo"]');
      if(any && (any.closest("header")||!header)) target=any;
    }
    if(target){
      if(target.tagName==="IMG"){
        target.src=base;target.alt="KRIM Logistics — Global Logistics Operating System";target.classList.add("krim-official-brand-logo");
      }else{
        var replacement=document.createElement("img");
        replacement.src=base;
        replacement.alt="KRIM Logistics — Global Logistics Operating System";
        replacement.className="krim-official-brand-logo";
        target.replaceWith(replacement);
      }
    }else{
      var bar=document.createElement("div");bar.className="krim-global-brandbar";
      var link=document.createElement("a");link.className="krim-global-brand-link";link.href="/logistics-saas/";link.setAttribute("aria-label","KRIM Logistics home");
      var img=document.createElement("img");img.src=base;img.alt="KRIM Logistics — Global Logistics Operating System";img.className="krim-official-brand-logo";link.appendChild(img);bar.appendChild(link);
      var body=document.body;
      if(header){header.insertBefore(link,header.firstChild);link.className="krim-global-brand-link";link.style.cssText="display:inline-flex;align-items:center;padding:6px 14px;max-width:100%;";}
      else if(body){body.insertBefore(bar,body.firstChild);}
    }
  }
  if(document.readyState==="loading") document.addEventListener("DOMContentLoaded",apply,{once:true}); else apply();
})();
