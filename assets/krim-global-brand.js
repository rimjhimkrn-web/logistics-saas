/* KRIM global brand lockup — idempotently enforces the approved full master logo. */
(function(){
  "use strict";
  var base="/logistics-saas/assets/krim-primary.svg?v=20261117-transparent-brand-v3";
  function apply(){
    if(document.documentElement.dataset.krimBrandApplied==="1") return;
    document.documentElement.dataset.krimBrandApplied="1";
    var header=document.querySelector("header");
    var candidates=[
      header&&header.querySelector(".brand-mark"),
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
        replacement.src=base;replacement.alt="KRIM Logistics — Global Logistics Operating System";
        replacement.className="krim-official-brand-logo";target.replaceWith(replacement);
      }
    }else{
      var brand=header&&header.querySelector(".brand,[class*='brand']");
      var img=document.createElement("img");
      img.src=base;img.alt="KRIM Logistics — Global Logistics Operating System";img.className="krim-official-brand-logo";
      img.style.cssText="display:block;width:190px;max-width:clamp(148px,48vw,190px);height:auto;max-height:60px;object-fit:contain;object-position:left center;flex:none;";
      if(brand){
        var subtitle=brand.querySelector("small");
        brand.replaceChildren(img);
        if(subtitle)brand.appendChild(subtitle);
        brand.style.cssText+="display:flex;align-items:center;gap:12px;min-width:0;";
      }else if(header){
        var link=document.createElement("a");link.href="/logistics-saas/";link.setAttribute("aria-label","KRIM Logistics home");link.appendChild(img);
        header.insertBefore(link,header.firstChild);
      }else if(document.body){
        var bar=document.createElement("div");bar.className="krim-global-brandbar";
        var link=document.createElement("a");link.className="krim-global-brand-link";link.href="/logistics-saas/";link.appendChild(img);bar.appendChild(link);
        document.body.insertBefore(bar,document.body.firstChild);
      }
    }
  }
  if(document.readyState==="loading") document.addEventListener("DOMContentLoaded",apply,{once:true}); else apply();
})();
