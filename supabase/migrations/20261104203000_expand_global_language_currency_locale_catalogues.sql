-- KRIM global language and currency catalogue expansion.
-- Repair stale catalogue sequences before inserts; the previous seed attempt
-- exposed that krim_locales_id_seq lagged behind existing rows.
select setval('public.krim_languages_id_seq', coalesce((select max(id) from public.krim_languages),0), true);
select setval('public.krim_locales_id_seq', coalesce((select max(id) from public.krim_locales),0), true);

-- Catalogue entries remain inactive until translations and locale QA pass.
insert into public.krim_languages (language_code,language_name,native_name,is_rtl,is_active) values
('ar','Arabic','العربية',true,false),('bn','Bengali','বাংলা',false,false),('de','German','Deutsch',false,false),
('es','Spanish','Español',false,false),('fr','French','Français',false,false),('gu','Gujarati','ગુજરાતી',false,false),
('id','Indonesian','Bahasa Indonesia',false,false),('it','Italian','Italiano',false,false),('ja','Japanese','日本語',false,false),
('ko','Korean','한국어',false,false),('ms','Malay','Bahasa Melayu',false,false),('mr','Marathi','मराठी',false,false),
('nl','Dutch','Nederlands',false,false),('pa','Punjabi','ਪੰਜਾਬੀ',false,false),('pl','Polish','Polski',false,false),
('pt','Portuguese','Português',false,false),('ru','Russian','Русский',false,false),('sw','Swahili','Kiswahili',false,false),
('ta','Tamil','தமிழ்',false,false),('te','Telugu','తెలుగు',false,false),('th','Thai','ไทย',false,false),
('tr','Turkish','Türkçe',false,false),('ur','Urdu','اردو',true,false),('vi','Vietnamese','Tiếng Việt',false,false),
('zh','Chinese','中文',false,false)
on conflict (language_code) do nothing;

insert into public.krim_currencies (code,name,symbol,decimal_places,decimal_digits,is_active) values
('AUD','Australian Dollar','A$',2,2,false),('BDT','Bangladeshi Taka','৳',2,2,false),
('BRL','Brazilian Real','R$',2,2,false),('CAD','Canadian Dollar','C$',2,2,false),
('CHF','Swiss Franc','CHF',2,2,false),('CNY','Chinese Yuan','¥',2,2,false),
('IDR','Indonesian Rupiah','Rp',2,2,false),('JPY','Japanese Yen','¥',0,0,false),
('KRW','South Korean Won','₩',0,0,false),('KWD','Kuwaiti Dinar','د.ك',3,3,false),
('MYR','Malaysian Ringgit','RM',2,2,false),('MXN','Mexican Peso','$',2,2,false),
('NZD','New Zealand Dollar','NZ$',2,2,false),('PHP','Philippine Peso','₱',2,2,false),
('PKR','Pakistani Rupee','₨',2,2,false),('QAR','Qatari Riyal','ر.ق',2,2,false),
('SAR','Saudi Riyal','﷼',2,2,false),('THB','Thai Baht','฿',2,2,false),
('TRY','Turkish Lira','₺',2,2,false),('TWD','New Taiwan Dollar','NT$',2,2,false),
('VND','Vietnamese Dong','₫',0,0,false),('ZAR','South African Rand','R',2,2,false)
on conflict (code) do nothing;

insert into public.krim_locales
(locale_code,language_code,country_code,date_format,time_format,number_format,first_day_of_week,is_active) values
('ar-AE','ar','AE','dd/MM/yyyy','HH:mm','#,##0.###',6,false),
('bn-BD','bn','BD','dd-MM-yyyy','hh:mm a','#,##,##0.###',0,false),
('de-DE','de','DE','dd.MM.yyyy','HH:mm','#,##0.###',1,false),
('es-ES','es','ES','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('fr-FR','fr','FR','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('gu-IN','gu','IN','dd/MM/yyyy','HH:mm','#,##,##0.###',1,false),
('id-ID','id','ID','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('it-IT','it','IT','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('ja-JP','ja','JP','yyyy/MM/dd','HH:mm','#,##0.###',0,false),
('ko-KR','ko','KR','yyyy. MM. dd.','a h:mm','#,##0.###',0,false),
('ms-MY','ms','MY','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('mr-IN','mr','IN','dd/MM/yyyy','HH:mm','#,##,##0.###',1,false),
('nl-NL','nl','NL','dd-MM-yyyy','HH:mm','#,##0.###',1,false),
('pa-IN','pa','IN','dd/MM/yyyy','HH:mm','#,##,##0.###',1,false),
('pl-PL','pl','PL','dd.MM.yyyy','HH:mm','#,##0.###',1,false),
('pt-BR','pt','BR','dd/MM/yyyy','HH:mm','#.##0,###',0,false),
('ru-RU','ru','RU','dd.MM.yyyy','HH:mm','#,##0.###',1,false),
('sw-KE','sw','KE','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('ta-IN','ta','IN','dd/MM/yyyy','HH:mm','#,##,##0.###',1,false),
('te-IN','te','IN','dd/MM/yyyy','HH:mm','#,##,##0.###',1,false),
('th-TH','th','TH','dd/MM/yyyy','HH:mm','#,##0.###',0,false),
('tr-TR','tr','TR','dd.MM.yyyy','HH:mm','#.##0,###',1,false),
('ur-PK','ur','PK','dd/MM/yyyy','HH:mm','#,##,##0.###',0,false),
('vi-VN','vi','VN','dd/MM/yyyy','HH:mm','#,##0.###',1,false),
('zh-CN','zh','CN','yyyy/MM/dd','HH:mm','#,##0.###',1,false)
on conflict (locale_code) do nothing;

comment on table public.krim_languages is 'Global language catalogue. Active means translation and accessibility QA has passed.';
comment on table public.krim_currencies is 'Currency catalogue. Active does not imply live FX, payment rails, settlement or payout availability.';
comment on table public.krim_locales is 'Locale catalogue. Active means product translation, formatting and country QA has passed.';
