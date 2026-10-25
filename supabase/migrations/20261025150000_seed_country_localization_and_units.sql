-- Seed verified baseline locale and measurement configuration for the six existing country records.
-- These are formatting defaults only; this does not activate additional operational markets.
INSERT INTO public.krim_unit_systems
  (id, system_code, name, distance_unit, weight_unit, volume_unit, temperature_unit, is_active)
VALUES
  (1, 'METRIC', 'Metric', 'km', 'kg', 'm3', 'C', true),
  (2, 'US_CUSTOMARY', 'US customary', 'mi', 'lb', 'ft3', 'F', true)
ON CONFLICT (system_code) DO UPDATE SET
  name = EXCLUDED.name,
  distance_unit = EXCLUDED.distance_unit,
  weight_unit = EXCLUDED.weight_unit,
  volume_unit = EXCLUDED.volume_unit,
  temperature_unit = EXCLUDED.temperature_unit,
  is_active = EXCLUDED.is_active;

INSERT INTO public.krim_locales
  (id, locale_code, language_code, country_code, date_format, time_format, number_format, first_day_of_week, is_active)
VALUES
  (1, 'en-IN', 'en', 'IN', 'dd/MM/yyyy', 'HH:mm', '#,##,##0.###', 1, true),
  (2, 'hi-IN', 'hi', 'IN', 'dd/MM/yyyy', 'HH:mm', '#,##,##0.###', 1, true),
  (3, 'en-AE', 'en', 'AE', 'dd/MM/yyyy', 'HH:mm', '#,##0.###', 1, true),
  (4, 'en-DE', 'en', 'DE', 'dd.MM.yyyy', 'HH:mm', '#,##0.###', 1, true),
  (5, 'en-GB', 'en', 'GB', 'dd/MM/yyyy', 'HH:mm', '#,##0.###', 1, true),
  (6, 'en-SG', 'en', 'SG', 'dd/MM/yyyy', 'HH:mm', '#,##0.###', 1, true),
  (7, 'en-US', 'en', 'US', 'MM/dd/yyyy', 'hh:mm a', '#,##0.###', 0, true)
ON CONFLICT (locale_code) DO UPDATE SET
  language_code = EXCLUDED.language_code,
  country_code = EXCLUDED.country_code,
  date_format = EXCLUDED.date_format,
  time_format = EXCLUDED.time_format,
  number_format = EXCLUDED.number_format,
  first_day_of_week = EXCLUDED.first_day_of_week,
  is_active = EXCLUDED.is_active;

INSERT INTO public.krim_country_localization
  (id, country_id, locale_id, unit_system_id, default_language_code, address_format, phone_format, currency_display, measurement_preferences)
VALUES
  (1, 1, 1, 1, 'en', '{"order":["address_line_1","address_line_2","city","state_region","postal_code","country"]}'::jsonb, '{"country_calling_code":"+91","national_number_digits":10}'::jsonb, '{"currency_code":"INR","display":"symbol","decimal_places":2}'::jsonb, '{"system":"METRIC","distance":"km","weight":"kg","volume":"m3","temperature":"C"}'::jsonb),
  (2, 2, 3, 1, 'en', '{"order":["address_line_1","address_line_2","city","region","postal_code","country"]}'::jsonb, '{"country_calling_code":"+971"}'::jsonb, '{"currency_code":"AED","display":"code","decimal_places":2}'::jsonb, '{"system":"METRIC","distance":"km","weight":"kg","volume":"m3","temperature":"C"}'::jsonb),
  (3, 3, 4, 1, 'en', '{"order":["address_line_1","address_line_2","postal_code","city","region","country"]}'::jsonb, '{"country_calling_code":"+49"}'::jsonb, '{"currency_code":"EUR","display":"symbol","decimal_places":2}'::jsonb, '{"system":"METRIC","distance":"km","weight":"kg","volume":"m3","temperature":"C"}'::jsonb),
  (4, 4, 5, 1, 'en', '{"order":["address_line_1","address_line_2","city","region","postal_code","country"]}'::jsonb, '{"country_calling_code":"+44"}'::jsonb, '{"currency_code":"GBP","display":"symbol","decimal_places":2}'::jsonb, '{"system":"METRIC","distance":"km","weight":"kg","volume":"m3","temperature":"C"}'::jsonb),
  (5, 5, 6, 1, 'en', '{"order":["address_line_1","address_line_2","city","region","postal_code","country"]}'::jsonb, '{"country_calling_code":"+65","national_number_digits":8}'::jsonb, '{"currency_code":"SGD","display":"code","decimal_places":2}'::jsonb, '{"system":"METRIC","distance":"km","weight":"kg","volume":"m3","temperature":"C"}'::jsonb),
  (6, 6, 7, 2, 'en', '{"order":["address_line_1","address_line_2","city","state_region","postal_code","country"]}'::jsonb, '{"country_calling_code":"+1"}'::jsonb, '{"currency_code":"USD","display":"symbol","decimal_places":2}'::jsonb, '{"system":"US_CUSTOMARY","distance":"mi","weight":"lb","volume":"ft3","temperature":"F"}'::jsonb)
ON CONFLICT (country_id) DO UPDATE SET
  locale_id = EXCLUDED.locale_id,
  unit_system_id = EXCLUDED.unit_system_id,
  default_language_code = EXCLUDED.default_language_code,
  address_format = EXCLUDED.address_format,
  phone_format = EXCLUDED.phone_format,
  currency_display = EXCLUDED.currency_display,
  measurement_preferences = EXCLUDED.measurement_preferences,
  updated_at = now();
