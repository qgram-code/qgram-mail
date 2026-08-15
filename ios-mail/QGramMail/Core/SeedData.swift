import Foundation

/// Демонстрационное содержимое ящика — перенесено 1:1 из макета.
enum SeedData {
    static let messages: [Message] = [
        Message(
            id: 1, folder: "INBOX", name: "Тимур Асланов", address: "t.aslanov@stroylink.ru",
            subject: "Договор на подпись — версия 4",
            preview: "Привет! Прикладываю финальную версию договора и смету. Правки от юристов внесены, осталась только подпись с вашей стороны.",
            time: "09:41", seen: false, flagged: false,
            attachments: [
                MailAttachment(name: "Договор_v4.pdf", ext: "PDF", meta: "application/pdf · 842 КБ"),
                MailAttachment(name: "Смета_август.xlsx", ext: "XLS", meta: "spreadsheet · 128 КБ")
            ],
            chips: [AuthChip(label: "DKIM"), AuthChip(label: "SPF"), AuthChip(label: "DMARC")],
            thread: [
                ThreadEntry(
                    name: "Вы", to: "t.aslanov@stroylink.ru", time: "вчера, 18:02",
                    body: "Тимур, добрый день! Посмотрел версию 3 — не хватает приложения со сметой. Пришлите, пожалуйста, вместе с финальной редакцией."
                ),
                ThreadEntry(
                    name: "Тимур Асланов", to: "nikita@qgram.im", time: "09:41",
                    body: """
                    Привет!

                    Прикладываю финальную версию договора и смету. Правки от юристов внесены, осталась только подпись с вашей стороны.

                    Если всё устраивает — подпишите и пришлите скан до пятницы, дальше мы запускаем работы по графику.

                    Спасибо,
                    Тимур
                    """
                )
            ]
        ),
        Message(
            id: 2, folder: "INBOX", name: "QGram Support", address: "support@qgram.im",
            subject: "Ваш ящик готов к работе",
            preview: "Адрес nikita@qgram.im активен. Пароль для IMAP/SMTP выдан один раз — если потеряли, выпустите новый в настройках.",
            time: "08:12", seen: false, flagged: false, attachments: [],
            chips: [AuthChip(label: "DKIM"), AuthChip(label: "SPF")],
            thread: [
                ThreadEntry(
                    name: "QGram Support", to: "nikita@qgram.im", time: "08:12",
                    body: """
                    Адрес nikita@qgram.im активен.

                    Пароль для почтовых клиентов выдаётся один раз — если он потерян, выпустите новый в настройках почты. Действуют лимиты на количество писем в час и в сутки.
                    """
                )
            ]
        ),
        Message(
            id: 3, folder: "INBOX", name: "Ирина Ковалёва", address: "i.kovaleva@qgram.im",
            subject: "Re: Дизайн-ревью в четверг",
            preview: "Перенесла на 15:00, переговорка занята до трёх. Скинула в тред ссылку на макеты и список вопросов.",
            time: "вчера", seen: true, flagged: false, attachments: [],
            chips: [AuthChip(label: "DKIM"), AuthChip(label: "DMARC")],
            thread: [
                ThreadEntry(
                    name: "Вы", to: "i.kovaleva@qgram.im", time: "пн, 12:10",
                    body: "Ир, давай ревью в четверг утром? Хочу успеть до релиза."
                ),
                ThreadEntry(
                    name: "Ирина Ковалёва", to: "nikita@qgram.im", time: "вчера, 16:44",
                    body: "Утро не выйдет — планёрка. Давай в 14:00?"
                ),
                ThreadEntry(
                    name: "Ирина Ковалёва", to: "nikita@qgram.im", time: "вчера, 17:20",
                    body: """
                    Перенесла на 15:00, переговорка занята до трёх.

                    Скинула в тред ссылку на макеты и список вопросов — посмотри заранее, чтобы не тратить время на введение.
                    """
                )
            ]
        ),
        Message(
            id: 4, folder: "INBOX", name: "Мария Лебедева", address: "m.lebedeva@qgram.im",
            subject: "Фотографии с выезда",
            preview: "Разобрала съёмку, отобрала 40 кадров. Полный архив лежит в облаке, здесь — лучшее.",
            time: "пн", seen: true, flagged: true,
            attachments: [
                MailAttachment(name: "vyezd-01.jpg", ext: "JPG", meta: "image/jpeg · 3,4 МБ"),
                MailAttachment(name: "vyezd-02.jpg", ext: "JPG", meta: "image/jpeg · 2,9 МБ")
            ],
            chips: [AuthChip(label: "SPF")],
            thread: [
                ThreadEntry(
                    name: "Мария Лебедева", to: "nikita@qgram.im", time: "пн, 21:03",
                    body: """
                    Разобрала съёмку, отобрала 40 кадров.

                    Полный архив лежит в облаке, здесь — два лучших кадра для анонса.
                    """
                )
            ]
        ),
        Message(
            id: 5, folder: "INBOX", name: "Селектел", address: "billing@selectel.ru",
            subject: "Счёт №4412 за август",
            preview: "Счёт сформирован, оплатите до 25 августа. Услуги: облачный сервер, объектное хранилище.",
            time: "12 авг", seen: false, flagged: false,
            attachments: [MailAttachment(name: "schet-4412.pdf", ext: "PDF", meta: "application/pdf · 96 КБ")],
            chips: [AuthChip(label: "DKIM"), AuthChip(label: "SPF"), AuthChip(label: "DMARC")],
            thread: [
                ThreadEntry(
                    name: "Селектел", to: "nikita@qgram.im", time: "12 авг, 10:05",
                    body: """
                    Счёт №4412 сформирован. Оплатите до 25 августа.

                    Услуги: облачный сервер, объектное хранилище.
                    """
                )
            ]
        ),
        Message(
            id: 6, folder: "INBOX", name: "Алексей Пронин", address: "a.pronin@qgram.im",
            subject: "Черновик статьи про SMTP",
            preview: "Дописал раздел про STARTTLS и порты. Посмотри вторую половину — там много спорного.",
            time: "11 авг", seen: true, flagged: false, attachments: [],
            chips: [AuthChip(label: "DKIM")],
            thread: [
                ThreadEntry(
                    name: "Алексей Пронин", to: "nikita@qgram.im", time: "11 авг, 19:31",
                    body: """
                    Дописал раздел про STARTTLS и порты.

                    Посмотри вторую половину — там много спорного, особенно про 465 против 587.
                    """
                )
            ]
        ),
        Message(
            id: 7, folder: "Junk", name: "Мега Скидки", address: "promo@mega-sale.biz",
            subject: "Только сегодня −80% на всё!",
            preview: "Успейте забрать промокод, предложение сгорает через 3 часа.",
            time: "10 авг", seen: true, flagged: false, attachments: [], chips: [],
            thread: [
                ThreadEntry(
                    name: "Мега Скидки", to: "nikita@qgram.im", time: "10 авг, 07:12",
                    body: "Успейте забрать промокод, предложение сгорает через 3 часа."
                )
            ]
        ),
        Message(
            id: 8, folder: "Sent", name: "Ирина Ковалёва", address: "i.kovaleva@qgram.im",
            subject: "Re: Дизайн-ревью в четверг",
            preview: "Ок, в 15:00 буду. Вопросы посмотрю сегодня вечером.",
            time: "вчера", seen: true, flagged: false, attachments: [], chips: [],
            thread: [
                ThreadEntry(
                    name: "Вы", to: "i.kovaleva@qgram.im", time: "вчера, 17:35",
                    body: "Ок, в 15:00 буду. Вопросы посмотрю сегодня вечером."
                )
            ]
        ),
        Message(
            id: 9, folder: "Drafts", name: "a.pronin@qgram.im", address: "a.pronin@qgram.im",
            subject: "Re: Черновик статьи про SMTP",
            preview: "Лёш, по 465 порту я бы всё-таки…",
            time: "11 авг", seen: true, flagged: false, attachments: [], chips: [],
            thread: [
                ThreadEntry(
                    name: "Вы", to: "a.pronin@qgram.im", time: "11 авг, 22:04",
                    body: "Лёш, по 465 порту я бы всё-таки…"
                )
            ]
        )
    ]
}
