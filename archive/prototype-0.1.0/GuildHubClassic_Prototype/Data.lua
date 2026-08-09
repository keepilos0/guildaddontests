GuildHubClassicPrototypeData = {
    guild = {
        name = "Лунные Стражи",
        motto = "Вместе — от первого квеста до последнего босса",
        online = 34,
        total = 126,
    },

    news = {
        {
            icon = "Interface\\Icons\\INV_Misc_Note_01",
            title = "Первый поход в Огненные Недра",
            text = "Сбор в субботу в 19:30. Проверяем зелья и сопротивление огню.",
            meta = "Сегодня · Элдарион",
        },
        {
            icon = "Interface\\Icons\\INV_Misc_Gift_04",
            title = "Неделя помощи новичкам",
            text = "Закрываем элитные задания и помогаем с первыми подземельями.",
            meta = "Вчера · Совет гильдии",
        },
    },

    requests = {
        { name = "Элария", class = "PRIEST", level = 42, text = "Нужна помощь с элитной цепочкой в Пылевых топях.", tag = "Квест" },
        { name = "Мордек", class = "ROGUE", level = 38, text = "Ищу 8 кусков толстой кожи для профессии.", tag = "Материалы" },
        { name = "Талия", class = "MAGE", level = 29, text = "Кто покажет короткий путь в Монастырь Алого ордена?", tag = "Подземелье" },
    },

    members = {
        { name = "Артанис", class = "WARRIOR", className = "Воин", level = 60, zone = "Оргриммар", status = "Готов к рейду", online = true },
        { name = "Лунара", class = "DRUID", className = "Друид", level = 60, zone = "Лунная поляна", status = "Готова помочь", online = true },
        { name = "Элария", class = "PRIEST", className = "Жрец", level = 42, zone = "Пылевые топи", status = "Ищет группу", online = true },
        { name = "Мордек", class = "ROGUE", className = "Разбойник", level = 38, zone = "Танарис", status = "Занят", online = true },
        { name = "Талия", class = "MAGE", className = "Маг", level = 29, zone = "Штормград", status = "Готова помочь", online = true },
        { name = "Бранн", class = "PALADIN", className = "Паладин", level = 55, zone = "Чумные земли", status = "Ищет группу", online = true },
        { name = "Рагнор", class = "HUNTER", className = "Охотник", level = 48, zone = "Осквернённый лес", status = "На задании", online = true },
        { name = "Сайлис", class = "WARLOCK", className = "Чернокнижник", level = 60, zone = "Чёрная гора", status = "В подземелье", online = true },
    },

    groups = {
        {
            icon = "Interface\\Icons\\INV_Misc_Map_01",
            title = "Глубины Чёрной горы",
            time = "Сегодня, 20:00",
            leader = "Артанис",
            members = "3 / 5",
            need = "Нужны лекарь и любой боец",
            difficulty = "Подземелье",
        },
        {
            icon = "Interface\\Icons\\INV_Misc_Key_14",
            title = "Монастырь Алого ордена",
            time = "Собираемся сейчас",
            leader = "Талия",
            members = "2 / 5",
            need = "Нужны танк, лекарь и боец",
            difficulty = "Задания",
        },
        {
            icon = "Interface\\Icons\\INV_Ore_Thorium_02",
            title = "Фарм тория",
            time = "Завтра, 18:30",
            leader = "Лунара",
            members = "2 / 4",
            need = "Спокойный совместный фарм",
            difficulty = "Открытый мир",
        },
    },

    tasks = {
        {
            icon = "Interface\\Icons\\INV_Potion_24",
            title = "Подготовить зелья для рейда",
            text = "Собрать 60 зелий защиты от огня.",
            progress = 42,
            goal = 60,
            reward = "+18 репутации",
            deadline = "До субботы",
        },
        {
            icon = "Interface\\Icons\\INV_Misc_Herb_17",
            title = "Запас трав для алхимиков",
            text = "Передать в банк 100 единиц чумоцвета.",
            progress = 67,
            goal = 100,
            reward = "+12 репутации",
            deadline = "Ещё 3 дня",
        },
        {
            icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
            title = "Наставники для новичков",
            text = "Найти трёх опытных наставников.",
            progress = 2,
            goal = 3,
            reward = "+8 репутации",
            deadline = "Без срока",
        },
        {
            icon = "Interface\\Icons\\INV_Misc_Rune_06",
            title = "Открыть проход в Ониксию",
            text = "Помочь участникам с цепочкой допуска.",
            progress = 11,
            goal = 20,
            reward = "+25 репутации",
            deadline = "До рейда",
        },
    },

    bank = {
        { icon = "Interface\\Icons\\INV_Fabric_PurpleFire_01", name = "Руническая ткань", count = 340, quality = 1, owner = "Складик", updated = "12 мин" },
        { icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01", name = "Чародейский кристалл", count = 7, quality = 2, owner = "Складик", updated = "12 мин" },
        { icon = "Interface\\Icons\\INV_Potion_24", name = "Зелье защиты от огня", count = 24, quality = 1, owner = "Рейдбанк", updated = "1 ч" },
        { icon = "Interface\\Icons\\INV_Misc_Herb_17", name = "Чумоцвет", count = 67, quality = 1, owner = "Травник", updated = "2 ч" },
        { icon = "Interface\\Icons\\INV_Enchant_ShardBrilliantLarge", name = "Большой сверкающий осколок", count = 18, quality = 3, owner = "Чаробанк", updated = "вчера" },
        { icon = "Interface\\Icons\\INV_Scroll_03", name = "Редкий рецепт алхимии", count = 1, quality = 3, owner = "Рецепты", updated = "3 дн" },
    },
}
