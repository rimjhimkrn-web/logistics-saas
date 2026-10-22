/* KRIM Customer OS shared workflow bridge.
 * Uses the existing config.js Supabase client; never reports a write as successful unless the server confirms it.
 */
(function(){
'use strict';
const root='../../';
const base='/logistics-saas/';
const path=(p)=>location.hostname.endsWith('github.io')?base+p.replace(/^\//,''):'/'+p.replace(/^\//,'');
const links=[
 ['Workspace','app/customer/index.html'],['Create shipment','public/shipments/shipment-create.html'],
 ['Quotes','public/customer/quote-request.html'],['Shipments','public/customer/shipment-list.html'],
 ['Tracking','public/visibility/live-tracking-map.html'],['Documents','public/documents/document-list.html'],
 ['Payments','public/finance/payment-checkout.html'],['Support','public/support/ticket-desk.html'],
 ['All customer pages','public/customer-os/index.html']
];
function announce(msg){let n=document.getElementById('krim-workflow-status');if(!n){n=document.createElement('div');n.id='krim-workflow-status';n.style.cssText='margin:12px auto;max-width:1100px;padding:10px 14px;border-radius:10px;background:#eaf2ff;color:#173b72;font:12px/1.5 system-ui';(document.querySelector('main')||document.body).prepend(n)}n.textContent=msg}
function nav(){if(document.getElementById('krim-global-customer-nav'))return;const n=document.createElement('nav');n.id='krim-global-customer-nav';n.setAttribute('aria-label','KRIM customer workflow');n.style.cssText='display:flex;gap:8px;flex-wrap:wrap;padding:12px max(16px,calc((100% - 1100px)/2));background:#fff;border-bottom:1px solid #dfe7f2;font:12px system-ui';n.innerHTML=links.map(([t,p])=>'<a style="padding:8px 11px;border-radius:8px;background:#f0f5ff;color:#174ea6;text-decoration:none;font-weight:700" href="'+path(p)+'">'+t+'</a>').join('');const h=document.querySelector('header');if(h&&h.parentNode)h.insertAdjacentElement('afterend',n);else document.body.prepend(n)}
async function init(){
 nav();
 const client=window.KRIM_SUPABASE||window.supabaseClient;
 if(!client){announce('KRIM workflow navigation is ready. Supabase client is not loaded on this page; no live account or record action was attempted.');return}
 try{
  const {data,error}=await client.auth.getSession();if(error)throw error;
  if(!data.session){announce('You are viewing the KRIM customer workflow. Sign in to access account-specific records.');return}
  const user=data.session.user;const badge=document.createElement('span');badge.textContent='Signed in · '+(user.email||'KRIM account');badge.style.cssText='margin-left:auto;padding:8px;color:#087e5b;font:700 12px system-ui';document.getElementById('krim-global-customer-nav').appendChild(badge);
  announce('Authenticated session detected. Customer records remain protected by Supabase policies; each transaction must be confirmed by its server response.');
 }catch(e){announce('Account status could not be verified. Refresh or sign in again before performing a transaction.')}
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();