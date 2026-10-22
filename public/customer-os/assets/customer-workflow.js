/* KRIM Customer OS workflow bridge — shared by the rebuilt customer/shipper pages.
   Navigation is global; identity checks use the existing Supabase client. Data changes remain server/RLS controlled. */
(function(){
'use strict';
const BASE='/logistics-saas/';
const route=p=>(location.hostname.endsWith('github.io')?BASE:'/')+p.replace(/^\//,'');
const links=[
 ['Customer Home','app/customer/index.html'],
 ['Create Shipment','public/shipments/shipment-create.html'],
 ['Quotes & Pricing','public/customer/quote-request.html'],
 ['Shipment Board','public/customer/shipment-list.html'],
 ['Live Tracking','public/visibility/live-tracking-map.html'],
 ['Documents','public/documents/document-list.html'],
 ['Payments','public/finance/payment-checkout.html'],
 ['Claims & Support','public/support/ticket-desk.html'],
 ['All Customer Pages','public/customer-os/index.html']
];
function status(message,kind){
 let box=document.getElementById('krim-workflow-status');
 if(!box){box=document.createElement('div');box.id='krim-workflow-status';(document.querySelector('main')||document.body).prepend(box)}
 box.textContent=message;
 box.style.cssText='margin:12px auto;max-width:1100px;padding:10px 14px;border-radius:10px;background:'+(kind==='ok'?'#e8f8f0':kind==='error'?'#fff0ef':'#eaf2ff')+';color:'+(kind==='ok'?'#086548':kind==='error'?'#a12820':'#173b72')+';font:12px/1.5 system-ui';
}
function addNavigation(){
 if(document.getElementById('krim-global-customer-nav'))return;
 const nav=document.createElement('nav');nav.id='krim-global-customer-nav';nav.setAttribute('aria-label','KRIM customer workflow');
 nav.style.cssText='display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding:12px max(16px,calc((100% - 1100px)/2));background:#fff;border-bottom:1px solid #dfe7f2;font:12px system-ui';
 nav.innerHTML=links.map(([label,target])=>'<a style="padding:8px 11px;border-radius:8px;background:#f0f5ff;color:#174ea6;text-decoration:none;font-weight:750" href="'+route(target)+'">'+label+'</a>').join('');
 const header=document.querySelector('header');if(header)header.insertAdjacentElement('afterend',nav);else document.body.prepend(nav);
}
async function verify(){
 addNavigation();
 const client=window.KRIM_SUPABASE||window.supabaseClient;
 if(!client){status('KRIM navigation is available. This page did not load a Supabase client, so account-specific records/actions are not enabled here.','error');return}
 try{
  const {data,error}=await client.auth.getSession();if(error)throw error;
  if(!data||!data.session){status('Public workflow page. Sign in to use account-specific records and protected actions.');return}
  const user=data.session.user;
  const result=await client.from('krim_organization_members').select('organization_id,role,status').eq('user_id',user.id).eq('status','active');
  if(result.error)throw result.error;
  if(!result.data||!result.data.length){status('Signed in as '+(user.email||'KRIM user')+', but no active KRIM organization membership was found. Contact your organization administrator.','error');return}
  const ids=[...new Set(result.data.map(x=>x.organization_id).filter(Boolean))];
  window.KRIM_CUSTOMER_WORKFLOW={userId:user.id,email:user.email,organizationIds:ids,memberships:result.data,client};
  const badge=document.createElement('span');badge.textContent='Verified session · '+(user.email||'KRIM account');badge.style.cssText='padding:8px;color:#087e5b;font:700 12px system-ui';
  const nav=document.getElementById('krim-global-customer-nav');if(nav)nav.appendChild(badge);
  status('Signed in and active organization membership verified. Records and transactions are still restricted by database permissions; this page will not claim a save unless the backend confirms it.','ok');
 }catch(e){status('Could not verify account access with KRIM. Refresh or sign in again. Details: '+(e&&e.message?e.message:'access check failed'),'error')}
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',verify);else verify();
})();