const i18next = require('i18next');
const Backend = require('i18next-fs-backend');
const i18nextMiddleware = require('i18next-http-middleware');
const path = require('path');
const env = require('./env');

i18next
  .use(Backend)
  .use(i18nextMiddleware.LanguageDetector)
  .init({
    fallbackLng: env.defaultLocale,
    preload: env.supportedLocales,
    supportedLngs: env.supportedLocales,
    ns: ['translation'],
    defaultNS: 'translation',
    backend: {
      loadPath: path.join(__dirname, '..', 'locales', '{{lng}}', '{{ns}}.json'),
    },
    detection: {
      // Clients send Accept-Language, or explicit ?lng=rw / X-Locale header.
      order: ['querystring', 'header'],
      lookupQuerystring: 'lng',
      lookupHeader: 'x-locale',
      caches: false,
    },
  });

module.exports = i18next;
