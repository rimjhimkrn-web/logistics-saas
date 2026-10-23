(function(){
'use strict';
const client=window.KRIM_SUPABASE||window.supabaseClient;
const $=id=>document.getElementById(id);
const view=document.body.dataset.quoteView||'list';
const quoteId=Number(new URLSearchParams(location.search).get('quote_id'));
const shipmentIdParam=new URLSearchParams(location.search).get('shipment_id');
let orgIds=[],quote=null,shipment=null;
function path(p){return window.krimPath?window.krimPath(p):p}
function say(text,kind){const el=$('feedback');el.textContent=text;el.className='notice'+(kind?' '+kind:'')}
function money(amount,currency){const n=Number(amount);if(!Number.isFinite(n))return 'Price not recorded';try{return new Intl.NumberFormat(undefined,{style:'currency',currency:String(currency||'INR').toUpperCase(),maximumFractionDigits:2}).format(n)}catch(_){return String(currency||'')+' '+n.toLocaleString()}}
function date(value){if(!value)return 'Not recorded';const d=new Date(value);return Number.isNaN(d.getTime())?'Not recorded':d.toLocaleString(undefined,{dateStyle:'medium',timeStyle:'short'})}
function el(tag,cls,text){const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n}
function renderList(rows){
 const root=$('quote-list');root.replaceChildren();
 if(!rows.length){const empty=el('section','empty');empty.append(el('h2','', 'No quote records found'),el('p','muted','Quotes appear here after the secured KRIM workflow creates records for your organization. No placeholder prices are shown.'));const a=el('a','btn primary','Request pricing →');a.href=path('public/customer/quote-request.html');empty.appendChild(a);root.appendChild(empty);return}
 rows.forEach(q=>{const card=el('article','quote-card');const top=el('div','quote-top');top.append(el('div','ref','QUOTE #'+q.id),el('span','pill',String(q.status||'pending').replace(/_/g,' ')));card.appendChild(top);card.appendChild(el('h2','',money(q.amount,q.currency_code)));card.appendChild(el('p','muted','Shipment #'+(q.shipment_id||'not linked')+' · Valid until '+date(q.valid_until)));card.appendChild(el('p','muted','Created '+date(q.created_at)));const actions=el('div','actions');const detail=el('a','btn','View quote details →');detail.href=path('public/customer-os/quotes-pricing/quote-details.html')+'?quote_id='+encodeURIComponent(q.id);actions.appendChild(detail);if(q.shipment_id){const compare=el('a','btn primary','Compare quotes');compare.href=path('public/shipper/quote-comparison.html')+'?shipment_id='+encodeURIComponent(q.shipment_id);actions.appendChild(compare)}card.appendChild(actions);root.appendChild(card)})
}
function field(label,value){const box=el('div','field');box.append(el('div','label',label),el('div','value',value||'Not recorded'));$('quote-fields').appendChild(box)}
async function access(){
 if(!client)throw new Error('KRIM backend configuration did not load. Refresh and retry.');
 const {data:auth,error:ae}=await client.auth.getSession();if(ae)throw ae;
 if(!auth?.session){location.replace(path('auth/login.html')+'?role=customer&next='+encodeURIComponent(location.pathname+location.search));return false}
 const {data:members,error:me}=await client.from('krim_organization_members').select('organization_id').eq('user_id',auth.session.user.id).eq('status','active');if(me)throw me;
 const ids=[...new Set((members||[]).map(m=>Number(m.organization_id)).filter(Number.isSafeInteger))];if(!ids.length)throw new Error('No active KRIM organization membership was found for this account.');
 const {data:orgs,error:oe}=await client.from('krim_organizations').select('id,organization_type,status').in('id',ids).eq('status','active');if(oe)throw oe;
 orgIds=(orgs||[]).filter(o=>['customer','shipper','enterprise'].includes(String(o.organization_type||'').toLowerCase())).map(o=>Number(o.id));if(!orgIds.length)throw new Error('This account has no active customer, shipper or enterprise organization.');
 return true
}
async function loadList(){
 say('Loading quote records visible to your active customer organization…');
 const {data,error}=await client.from('krim_quotes').select('id,shipment_id,customer_organization_id,amount,currency_code,status,valid_until,partner_quote_id,created_at').in('customer_organization_id',orgIds).order('created_at',{ascending:false}).limit(100);if(error)throw error;
 renderList(data||[]);say('Loaded '+(data||[]).length+' database quote records. Values shown here are not generated or estimated by the interface.')
}
async function loadDetail(){
 if(!Number.isSafeInteger(quoteId)||quoteId<=0){say('A valid quote_id is required. Open a quote from your quote register.','warn');$('quote-actions').classList.add('hidden');return}
 const {data:q,error:qe}=await client.from('krim_quotes').select('id,shipment_id,customer_organization_id,amount,currency_code,status,valid_until,partner_quote_id,created_at').eq('id',quoteId).in('customer_organization_id',orgIds).maybeSingle();if(qe)throw qe;
 if(!q){say('Quote not found in your authorized customer organizations. No record outside your organization was displayed.','error');$('quote-actions').classList.add('hidden');return}
 quote=q;
 const {data:s,error:se}=await client.from('krim_shipments').select('id,shipment_number,customer_organization_id,origin_place_label,destination_place_label,goods_description,requested_transport_mode,status').eq('id',Number(q.shipment_id)).in('customer_organization_id',orgIds).maybeSingle();if(se)throw se;shipment=s||null;
 $('quote-fields').replaceChildren();
 field('Quote reference','#'+q.id);field('Quote status',String(q.status||'pending').replace(/_/g,' '));field('Quoted amount',money(q.amount,q.currency_code));field('Currency',String(q.currency_code||'Not recorded').toUpperCase());field('Valid until',date(q.valid_until));field('Created',date(q.created_at));field('Shipment reference',shipment?.shipment_number||('#'+q.shipment_id));field('Origin',shipment?.origin_place_label||'Not recorded');field('Destination',shipment?.destination_place_label||'Not recorded');field('Transport mode',shipment?.requested_transport_mode||'Not recorded');field('Cargo',shipment?.goods_description||'Not recorded');field('Shipment status',shipment?.status||'Not recorded');
 const accepted=String(q.status||'').toLowerCase()==='accepted',expired=q.valid_until&&new Date(q.valid_until).getTime()<=Date.now();
 $('accept-button').classList.toggle('hidden',view!=='acceptance');$('compare-link').href=path('public/shipper/quote-comparison.html')+'?shipment_id='+encodeURIComponent(q.shipment_id||'');$('detail-link').href=path('public/customer-os/quotes-pricing/quote-details.html')+'?quote_id='+encodeURIComponent(q.id);
 if(view==='acceptance'){
  const button=$('accept-button');button.disabled=accepted||!!expired||Number(q.amount)<=0||!shipment;
  button.textContent=accepted?'Quote already accepted':expired?'Quote expired':'Accept quote securely';
  if(!shipment)say('The linked shipment could not be verified inside your organization. Quote acceptance is blocked.','error');
  else if(accepted)say('This quote is already marked accepted by the database. Booking, partner assignment and payment remain separate checks.');
  else if(expired)say('This quote has expired. KRIM will not attempt to accept an expired quote.','warn');
  else say('Review the amount, currency and validity before acceptance. KRIM revalidates eligibility on the server.','')
 }else say('Quote and shipment records are scoped to your active customer organization. This view does not imply booking or payment completion.')
}
$('accept-button').addEventListener('click',async()=>{
 if(!quote||!shipment||!quoteId)return;
 if(!confirm('Accept quote #'+quote.id+' for '+money(quote.amount,quote.currency_code)+'? KRIM will validate quote eligibility and permissions on the server.'))return;
 const b=$('accept-button');b.disabled=true;b.textContent='Validating and accepting…';say('Waiting for KRIM server-side quote acceptance…');
 try{
  const {data,error}=await client.rpc('krim_accept_global_quote',{p_quote_id:Number(quote.id)});if(error)throw error;
  const result=Array.isArray(data)?data[0]:data;if(!result||Number(result.id)!==Number(quote.id)||String(result.status)!=='accepted')throw new Error('The server did not confirm acceptance of this exact quote.');
  quote.status='accepted';b.textContent='Quote accepted ✓';say('KRIM confirmed quote acceptance. Partner assignment, final booking and payment still require their own verified states.');
  const a=$('compare-link');a.textContent='Return to quote comparison →';a.href=path('public/shipper/quote-comparison.html')+'?shipment_id='+encodeURIComponent(quote.shipment_id);
 }catch(e){say((e&&e.message)||'Quote acceptance failed. Refresh and review the current quote status.','error');b.disabled=false;b.textContent='Accept quote securely'}
});
async function init(){if(!await access())return;if(view==='list')await loadList();else await loadDetail()}
init().catch(e=>{console.error(e);say((e&&e.message)||'Unable to load quote records. No action was completed.','error')});
})();