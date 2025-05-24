-- Отключить сообщения о количестве затронутых строк для лучшей читаемости
SET NOCOUNT ON;

-- Объявление переменных
DECLARE @NumWorks INT = 50000; -- Количество заказов для генерации
DECLARE @AvgWorkItems INT = 3; -- Среднее количество элементов в заказе
DECLARE @i INT = 1;
DECLARE @j INT = 1;
DECLARE @Id_Work INT;
DECLARE @Id_Employee INT;
DECLARE @Id_Analiz INT;
DECLARE @StatusId SMALLINT;

-- 1. Очистка таблиц (если вы запускаете скрипт несколько раз)
-- Важно: Удалять в обратном порядке зависимостей внешних ключей
DELETE FROM WorkItem; -- Зависит от Works и Analiz
DELETE FROM Works;    -- Зависит от Employee, WorkStatus, Organization (хотя Organization пока пуста)
DELETE FROM Employee;
DELETE FROM Analiz;
DELETE FROM WorkStatus;

-- 2. Вставка данных в WorkStatus (статусы заказа)
INSERT INTO WorkStatus (StatusName) VALUES ('В ожидании');
INSERT INTO WorkStatus (StatusName) VALUES ('В процессе');
INSERT INTO WorkStatus (StatusName) VALUES ('Завершено');
INSERT INTO WorkStatus (StatusName) VALUES ('Отменено');
INSERT INTO WorkStatus (StatusName) VALUES ('Напечатано');

-- 3. Вставка данных в Employee (сотрудники)
INSERT INTO Employee (Login_Name, Name, Patronymic, Surname, CreateDate, Archived, IS_Role)
VALUES ('jdoe', 'John', 'A.', 'Doe', GETDATE(), 0, 0);
INSERT INTO Employee (Login_Name, Name, Patronymic, Surname, CreateDate, Archived, IS_Role)
VALUES ('asmith', 'Anna', 'M.', 'Smith', GETDATE(), 0, 0);
INSERT INTO Employee (Login_Name, Name, Patronymic, Surname, CreateDate, Archived, IS_Role)
VALUES ('bwill', 'Bob', 'K.', 'Williams', GETDATE(), 0, 0);

-- 4. Вставка данных в Analiz (спецификации анализа)
INSERT INTO Analiz (IS_GROUP, MATERIAL_TYPE, CODE_NAME, FULL_NAME, Price)
VALUES (0, 1, 'ANA001', 'Полный анализ крови', 25.50);
INSERT INTO Analiz (IS_GROUP, MATERIAL_TYPE, CODE_NAME, FULL_NAME, Price)
VALUES (0, 1, 'ANA002', 'Анализ мочи', 15.00);
INSERT INTO Analiz (IS_GROUP, MATERIAL_TYPE, CODE_NAME, FULL_NAME, Price)
VALUES (1, 2, 'ANA003_GRP', 'Группа гормональных анализов', 80.00); -- Пример группы
INSERT INTO Analiz (IS_GROUP, MATERIAL_TYPE, CODE_NAME, FULL_NAME, Price)
VALUES (0, 1, 'ANA004', 'Липидный профиль', 40.00);
INSERT INTO Analiz (IS_GROUP, MATERIAL_TYPE, CODE_NAME, FULL_NAME, Price)
VALUES (0, 2, 'ANA005', 'Бактериальная культура', 30.00);

-- Получить максимальные ID для циклов
SELECT @Id_Employee = MAX(Id_Employee) FROM Employee;
SELECT @Id_Analiz = MAX(ID_ANALIZ) FROM Analiz;
SELECT @StatusId = MAX(StatusID) FROM WorkStatus;


-- 5. Генерация заказов (Works)
WHILE @i <= @NumWorks
BEGIN
    INSERT INTO Works (IS_Complit, CREATE_Date, Id_Employee, MaterialNumber, FIO, StatusId, Is_Del)
    VALUES (
        CAST(ROUND(RAND(CHECKSUM(NEWID())), 0) AS BIT), -- Is_Complit (0 или 1)
        DATEADD(day, -CAST(RAND(CHECKSUM(NEWID())) * 365 * 2 AS INT), GETDATE()), -- CREATE_Date (до 2 лет назад)
        CEILING(RAND(CHECKSUM(NEWID())) * @Id_Employee), -- Случайный Id_Employee
        ROUND(RAND(CHECKSUM(NEWID())) * 1000, 2), -- Случайный MaterialNumber
        'Client FIO ' + CAST(@i AS VARCHAR(10)), -- ФИО
        CEILING(RAND(CHECKSUM(NEWID())) * @StatusId), -- Случайный StatusId
        0 -- Is_Del (не удалено)
    );

    SET @Id_Work = SCOPE_IDENTITY(); -- Получает ID только что вставленного заказа

    -- Генерация элементов заказа (WorkItem) для этого заказа
    SET @j = 1;
    DECLARE @NumWorkItems INT = CEILING(RAND(CHECKSUM(NEWID())) * (@AvgWorkItems * 2 - 1) + 1); -- От 1 до (AvgWorkItems * 2 - 1)
    -- Идея состоит в том, чтобы иметь среднее значение около @AvgWorkItems. Здесь это даст распределение от 1 до 5 для среднего значения 3.

    WHILE @j <= @NumWorkItems
    BEGIN
        INSERT INTO WorkItem (CREATE_DATE, Is_Complit, Id_Work, ID_ANALIZ, Is_Print, Is_Select, Is_NormTextPrint)
        VALUES (
            DATEADD(hour, CAST(RAND(CHECKSUM(NEWID())) * 24 AS INT), GETDATE()), -- CREATE_DATE (случайная дата в течение дня)
            CAST(ROUND(RAND(CHECKSUM(NEWID())), 0) AS BIT), -- Is_Complit (0 или 1)
            @Id_Work,
            CEILING(RAND(CHECKSUM(NEWID())) * @Id_Analiz), -- Случайный ID_ANALIZ
            CAST(ROUND(RAND(CHECKSUM(NEWID())), 0) AS BIT), -- Is_Print (0 или 1)
            CAST(ROUND(RAND(CHECKSUM(NEWID())), 0) AS BIT), -- Is_Select (0 или 1)
            CAST(ROUND(RAND(CHECKSUM(NEWID())), 0) AS BIT) -- Is_NormTextPrint (0 или 1)
        );
        SET @j = @j + 1;
    END;

    SET @i = @i + 1;
END;

PRINT 'Генерация данных завершена. Вставлено ' + CAST(@NumWorks AS VARCHAR) + ' заказов.';