/* KRIM Global Customer Context — shared, read-only presentation layer.
   User preferences control display only. They never activate a market, corridor,
   carrier, rate, payment rail, tax treatment or regulatory permission. */
(function (w, d) {
  'use strict';
  if (w.KRIM_GLOBAL_CONTEXT) return;
  const staging = location.hostname.endsWith('.krim-staging.pages.dev');
  const rtl = new Set(['ar','fa','he','ur','ps','sd','yi']);
  const state = {
    ready: false, staging, locale: navigator.language || 'en',
    language: (navigator.language || 'en').split('-')[0],
    country: null, currency: null, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
    measurementSystem: 'metric', dateFormat: 'locale', numberFormat: 'locale'
  };
  const api = {
    get preferences() { return Object.freeze({...state}); },
    formatNumber(value, options) {
      const n=Number(value);
      if (!Number.isFinite(n)) return '';
      if (!options && state.numberFormat !== 'locale') {
        const raw = new Intl.NumberFormat('en-US',{useGrouping:false,maximumFractionDigits:20}).format(n).split('.');
        const group = state.numberFormat === '1 234,56' ? ' ' : state.numberFormat === '1.234,56' ? '.' : ',';
        const decimal = state.numberFormat === '1,234.56' ? '.' : ',';
        const integer = raw[0].replace(/\\B(?=(\\d{3})+(?!\\d))/g, group);
        return integer + (raw[1] ? decimal + raw[1] : '');
      }
      return new Intl.NumberFormat(state.locale, options || {}).format(n);
    },
    formatCurrency(value, currency) {
      const code = currency || state.currency;
      if (!code) return api.formatNumber(value);
      try { return new Intl.NumberFormat(state.locale, {style:'currency',currency:code}).format(Number(value)); }
      catch (_) { return api.formatNumber(value) + ' ' + code; }
    },
    formatDate(value, options) {
      const date = value instanceof Date ? value : new Date(value);
      if (Number.isNaN(date.getTime())) return '';
      return new Intl.DateTimeFormat(state.locale, {...(options || {}), timeZone:state.timeZone}).format(date);
    },
    formatDateTime(value, options) {
      return api.formatDate(value, {dateStyle:'medium',timeStyle:'short',...(options || {})});
    },
    formatWeight(valueKg, unit) {
      const kg = Number(valueKg);
      if (!Number.isFinite(kg)) return '';
      const chosen = unit || (state.measurementSystem === 'metric' ? 'kg' : state.measurementSystem === 'us_customary' ? 'lb' : 'lb');
      const factors = {kg:1,g:1000,t:0.001,lb:2.2046226218,short_ton:0.0011023113,long_ton:0.0009842065,stone:0.1574730444};
      const converted = kg * (factors[chosen] || 1);
      const digits = Math.abs(converted) < 1 ? 3 : 2;
      return api.formatNumber(Number(converted.toFixed(digits))) + ' ' + chosen;
    },
    formatLength(valueMetres, unit) {
      const m = Number(valueMetres);
      if (!Number.isFinite(m)) return '';
      const chosen = unit || (state.measurementSystem === 'metric' ? 'm' : 'ft');
      const factors = {m:1,cm:100,mm:1000,km:0.001,ft:3.280839895,in:39.37007874,mi:0.0006213712};
      return api.formatNumber(Number((m * (factors[chosen] || 1)).toFixed(3))) + ' ' + chosen;
    },
    async refresh() {
      const client = w.KRIM_SUPABASE || w.supabaseClient;
      if (staging || !client || !client.auth) { state.ready = true; d.documentElement.dataset.krimGlobalContext = 'ready'; return api.preferences; }
      try {
        const {data: auth, error: authError} = await client.auth.getSession();
        if (authError || !auth?.session?.user) { state.ready = true; d.documentElement.dataset.krimGlobalContext = 'ready'; return api.preferences; }
        const {data, error} = await client.from('krim_user_app_preferences').select('preferences').eq('user_id', auth.session.user.id).maybeSingle();
        if (error) throw error;
        const p = data?.preferences || {}, r = p.customer_localization || {};
        if (typeof r.language_code === 'string' && /^[a-z]{2,3}(-[A-Z]{2})?$/.test(r.language_code)) {
          state.language = r.language_code.split('-')[0]; state.locale = r.language_code.includes('-') ? r.language_code : (r.country_code ? r.language_code+'-'+r.country_code : r.language_code);
          d.documentElement.lang = r.language_code;
          d.documentElement.dir = rtl.has(state.language) ? 'rtl' : 'ltr';
        }
        if (typeof r.country_code === 'string' && /^[A-Z]{2}$/.test(r.country_code)) state.country = r.country_code;
        if (typeof r.currency_code === 'string' && /^[A-Z]{3}$/.test(r.currency_code)) state.currency = r.currency_code;
        if (typeof r.timezone === 'string') { try { new Intl.DateTimeFormat('en',{timeZone:r.timezone}); state.timeZone = r.timezone; } catch (_) {} }
        if (['metric','us_customary','uk_imperial'].includes(r.measurement_system)) state.measurementSystem = r.measurement_system;
        if (typeof r.date_format === 'string') state.dateFormat = r.date_format;
        if (typeof r.number_format === 'string') state.numberFormat = r.number_format;
      } catch (error) {
        console.warn('[KRIM global context] Preferences could not be loaded; using device locale.', error);
      }
      state.ready = true;
      d.documentElement.dataset.krimGlobalContext = 'ready';
      d.dispatchEvent(new CustomEvent('krim:global-context-ready',{detail:api.preferences}));
      return api.preferences;
    }
  };
  w.KRIM_GLOBAL_CONTEXT = api;
  api.ready = api.refresh();
})(window, document);
