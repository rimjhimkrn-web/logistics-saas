(function (global) {
  "use strict";

  const common = {
    en: { home: "Home", dashboard: "Overview", services: "Services", requestQuote: "Request a quote", trackShipment: "Track shipment", shipments: "Shipments", documents: "Documents", notifications: "Notifications", support: "Support", signIn: "Sign in", signOut: "Sign out", pickup: "Pickup location", delivery: "Delivery location", requestSent: "Your request was received.", unavailable: "This information is not connected yet.", language: "Language" },
    hi: { home: "होम", dashboard: "अवलोकन", services: "सेवाएँ", requestQuote: "कोटेशन माँगें", trackShipment: "शिपमेंट ट्रैक करें", shipments: "शिपमेंट", documents: "दस्तावेज़", notifications: "सूचनाएँ", support: "सहायता", signIn: "साइन इन", signOut: "साइन आउट", pickup: "पिकअप स्थान", delivery: "डिलीवरी स्थान", requestSent: "आपका अनुरोध प्राप्त हुआ।", unavailable: "यह जानकारी अभी कनेक्ट नहीं है।", language: "भाषा" },
    ar: { home: "الرئيسية", dashboard: "نظرة عامة", services: "الخدمات", requestQuote: "اطلب عرض سعر", trackShipment: "تتبع الشحنة", shipments: "الشحنات", documents: "المستندات", notifications: "الإشعارات", support: "الدعم", signIn: "تسجيل الدخول", signOut: "تسجيل الخروج", pickup: "موقع الاستلام", delivery: "موقع التسليم", requestSent: "تم استلام طلبك.", unavailable: "هذه المعلومات غير متصلة بعد.", language: "اللغة" },
    es: { home: "Inicio", dashboard: "Resumen", services: "Servicios", requestQuote: "Solicitar cotización", trackShipment: "Rastrear envío", shipments: "Envíos", documents: "Documentos", notifications: "Notificaciones", support: "Soporte", signIn: "Iniciar sesión", signOut: "Cerrar sesión", pickup: "Lugar de recogida", delivery: "Lugar de entrega", requestSent: "Hemos recibido tu solicitud.", unavailable: "Esta información aún no está conectada.", language: "Idioma" },
    fr: { home: "Accueil", dashboard: "Vue d’ensemble", services: "Services", requestQuote: "Demander un devis", trackShipment: "Suivre un envoi", shipments: "Expéditions", documents: "Documents", notifications: "Notifications", support: "Assistance", signIn: "Se connecter", signOut: "Se déconnecter", pickup: "Lieu d’enlèvement", delivery: "Lieu de livraison", requestSent: "Votre demande a été reçue.", unavailable: "Ces informations ne sont pas encore connectées.", language: "Langue" },
    pt: { home: "Início", dashboard: "Visão geral", services: "Serviços", requestQuote: "Solicitar cotação", trackShipment: "Rastrear remessa", shipments: "Remessas", documents: "Documentos", notifications: "Notificações", support: "Suporte", signIn: "Entrar", signOut: "Sair", pickup: "Local de coleta", delivery: "Local de entrega", requestSent: "Sua solicitação foi recebida.", unavailable: "Estas informações ainda não estão conectadas.", language: "Idioma" },
    de: { home: "Start", dashboard: "Übersicht", services: "Leistungen", requestQuote: "Angebot anfragen", trackShipment: "Sendung verfolgen", shipments: "Sendungen", documents: "Dokumente", notifications: "Benachrichtigungen", support: "Support", signIn: "Anmelden", signOut: "Abmelden", pickup: "Abholort", delivery: "Lieferort", requestSent: "Ihre Anfrage wurde empfangen.", unavailable: "Diese Informationen sind noch nicht verbunden.", language: "Sprache" },
    it: { home: "Home", dashboard: "Panoramica", services: "Servizi", requestQuote: "Richiedi un preventivo", trackShipment: "Traccia spedizione", shipments: "Spedizioni", documents: "Documenti", notifications: "Notifiche", support: "Assistenza", signIn: "Accedi", signOut: "Esci", pickup: "Luogo di ritiro", delivery: "Luogo di consegna", requestSent: "La richiesta è stata ricevuta.", unavailable: "Queste informazioni non sono ancora collegate.", language: "Lingua" },
    nl: { home: "Start", dashboard: "Overzicht", services: "Diensten", requestQuote: "Offerte aanvragen", trackShipment: "Zending volgen", shipments: "Zendingen", documents: "Documenten", notifications: "Meldingen", support: "Ondersteuning", signIn: "Inloggen", signOut: "Uitloggen", pickup: "Ophaallocatie", delivery: "Bezorglocatie", requestSent: "Je aanvraag is ontvangen.", unavailable: "Deze informatie is nog niet gekoppeld.", language: "Taal" },
    tr: { home: "Ana sayfa", dashboard: "Genel bakış", services: "Hizmetler", requestQuote: "Teklif isteyin", trackShipment: "Gönderiyi takip edin", shipments: "Gönderiler", documents: "Belgeler", notifications: "Bildirimler", support: "Destek", signIn: "Giriş yap", signOut: "Çıkış yap", pickup: "Alım konumu", delivery: "Teslimat konumu", requestSent: "Talebiniz alındı.", unavailable: "Bu bilgiler henüz bağlı değil.", language: "Dil" },
    zh: { home: "首页", dashboard: "概览", services: "服务", requestQuote: "申请报价", trackShipment: "追踪货件", shipments: "货件", documents: "文件", notifications: "通知", support: "支持", signIn: "登录", signOut: "退出", pickup: "取货地点", delivery: "送达地点", requestSent: "已收到您的请求。", unavailable: "此信息尚未连接。", language: "语言" },
    ja: { home: "ホーム", dashboard: "概要", services: "サービス", requestQuote: "見積もりを依頼", trackShipment: "貨物を追跡", shipments: "貨物", documents: "書類", notifications: "通知", support: "サポート", signIn: "サインイン", signOut: "サインアウト", pickup: "集荷場所", delivery: "配送先", requestSent: "リクエストを受け付けました。", unavailable: "この情報はまだ接続されていません。", language: "言語" },
    ko: { home: "홈", dashboard: "개요", services: "서비스", requestQuote: "견적 요청", trackShipment: "화물 추적", shipments: "화물", documents: "문서", notifications: "알림", support: "지원", signIn: "로그인", signOut: "로그아웃", pickup: "픽업 위치", delivery: "배송 위치", requestSent: "요청이 접수되었습니다.", unavailable: "이 정보는 아직 연결되지 않았습니다.", language: "언어" },
    ru: { home: "Главная", dashboard: "Обзор", services: "Услуги", requestQuote: "Запросить расчёт", trackShipment: "Отследить отправление", shipments: "Отправления", documents: "Документы", notifications: "Уведомления", support: "Поддержка", signIn: "Войти", signOut: "Выйти", pickup: "Место забора", delivery: "Место доставки", requestSent: "Запрос получен.", unavailable: "Эта информация пока не подключена.", language: "Язык" },
    bn: { home: "হোম", dashboard: "সংক্ষিপ্ত বিবরণ", services: "পরিষেবা", requestQuote: "দরপত্রের অনুরোধ", trackShipment: "চালান ট্র্যাক করুন", shipments: "চালান", documents: "নথি", notifications: "বিজ্ঞপ্তি", support: "সহায়তা", signIn: "সাইন ইন", signOut: "সাইন আউট", pickup: "পিকআপের স্থান", delivery: "ডেলিভারির স্থান", requestSent: "আপনার অনুরোধ গ্রহণ করা হয়েছে।", unavailable: "এই তথ্য এখনো সংযুক্ত নয়।", language: "ভাষা" }
  };

  const languageCoverage = {
    en: "Some page content is currently available only in English.",
    hi: "कुछ पृष्ठों की सामग्री अभी केवल अंग्रेज़ी में उपलब्ध है।",
    ar: "يتوفر بعض محتوى الصفحات حاليًا باللغة الإنجليزية فقط.",
    es: "Parte del contenido de las páginas solo está disponible en inglés.",
    fr: "Une partie du contenu des pages est uniquement disponible en anglais.",
    pt: "Parte do conteúdo das páginas está disponível apenas em inglês.",
    de: "Einige Seiteninhalte sind derzeit nur auf Englisch verfügbar.",
    it: "Alcuni contenuti delle pagine sono attualmente disponibili solo in inglese.",
    nl: "Sommige pagina-inhoud is momenteel alleen beschikbaar in het Engels.",
    tr: "Bazı sayfa içerikleri şu anda yalnızca İngilizce olarak sunulmaktadır.",
    zh: "部分页面内容目前仅提供英文版本。",
    ja: "一部のページ内容は現在英語のみでご利用いただけます。",
    ko: "일부 페이지 콘텐츠는 현재 영어로만 제공됩니다.",
    ru: "Некоторые материалы страниц сейчас доступны только на английском языке.",
    bn: "কিছু পৃষ্ঠার বিষয়বস্তু বর্তমানে শুধু ইংরেজিতে পাওয়া যায়。"
  };
  Object.entries(languageCoverage).forEach(([language, message]) => {
    common[language].languageCoverage = message;
  });

  global.KRIM_CATALOG = Object.freeze(common);
})(window);