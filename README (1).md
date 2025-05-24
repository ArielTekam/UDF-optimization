# Optimisation-DB

# Оптимизация функции (UDF) возврата списка заказов

## Контекст проекта
Данный проект направлен на оптимизацию пользовательской функции (UDF) `dbo.F_WORKS_LIST()` в базе данных MS SQL Server, которая используется клиентским приложением для получения списка заказов. Пользователи сообщают о низкой производительности при загрузке этого списка, при этом отсутствует возможность отладить приложение и внести в него правки. Цель состоит в том, чтобы улучшить производительность этой функции, изменяя только объекты базы данных.

## Требования к окружению
- MS SQL Server (любая версия, включая SQL Server для Linux или Windows).
- Допустимо использование иной СУБД при портировании исходного скрипта с учётом конечного диалекта SQL.

## Начальные действия
1. Ознакомление со скриптом создания базы данных.
2. Ознакомление с программными компонентами (функциями).
3. Разработка и применение генератора тестовых данных.

Целью этих начальных шагов является получение базы данных с тестовыми данными, готовой к оптимизации.

**Текущее состояние**: База данных создана и заполнена 50 000 заказами и 200 026 элементами заказов.

**Доказательства начального состояния**:
Количество строк в таблицах:
- Works: 50000
- WorkItem: 200026
- Employee: 3
- Analiz: 5
- WorkStatus: 5

## Выявленная проблема
Пользователи приложения сообщают о низкой производительности при загрузке списка заказов с помощью запроса `select top 3000 * from dbo.F_WORKS_LIST()`. Отсутствует возможность отладить приложение и внести в него правки.

## Задача 1-го уровня: Анализ проблем производительности dbo.F_WORKS_LIST()
**Выявленные недостатки и потенциальные проблемы производительности (Исходная версия функции)**:
1. **Многооператорная табличная функция (MSTVF)**: Функция F_WORKS_LIST была MSTVF. MSTVF неэффективны, поскольку оптимизатору запросов SQL Server сложно оценить количество возвращаемых строк, что приводит к неоптимальным планам выполнения.
2. **Построчные вызовы скалярных функций**: 
   - `dbo.F_WORKITEMS_COUNT_BY_ID_WORK(works.Id_Work,0)`
   - `dbo.F_WORKITEMS_COUNT_BY_ID_WORK(works.Id_Work,1)`
   - `dbo.F_EMPLOYEE_FULLNAME(Works.Id_Employee)`
3. **Стоимость скалярных функций**:
   - `F_WORKITEMS_COUNT_BY_ID_WORK` включала повторяющийся подзапрос `NOT IN (SELECT ID_ANALIZ FROM Analiz WHERE IS_GROUP = 1)`
   - `F_EMPLOYEE_FULLNAME` выполняла поиск в таблице Employee для каждого вызова
4. **Отсутствие соответствующих индексов**

**Измерение начальной производительности (Базовый уровень)**:
- Время выполнения: elapsed time 39058 мс (около 39 секунд)
- Время ЦП: CPU time 38021 мс
- План выполнения: Операция Table Valued Function [F_WORKS_LIST] составляла 46% от общей стоимости

## Задача 2-го уровня: Предложить правки запросов без модификации структуры БД
**Цель**: Оптимизировать функцию F_WORKS_LIST для достижения времени выполнения менее 1-2 секунд при получении 3 000 заказов.

### Первая оптимизация: Рефакторинг скалярных функций и преобразование в ITVF
**Внесенные изменения**:
- Преобразование F_WORKS_LIST во встроенную табличную функцию (ITVF)
- Удаление вызовов скалярных функций и интеграция их логики в основной запрос

```sql
-- Удаление старых функций
IF OBJECT_ID('dbo.F_WORKS_LIST', 'TF') IS NOT NULL DROP FUNCTION [dbo].[F_WORKS_LIST]; GO
IF OBJECT_ID('dbo.F_WORKITEMS_COUNT_BY_ID_WORK', 'FN') IS NOT NULL DROP FUNCTION [dbo].[F_WORKITEMS_COUNT_BY_ID_WORK]; GO
IF OBJECT_ID('dbo.F_EMPLOYEE_FULLNAME', 'FN') IS NOT NULL DROP FUNCTION [dbo].[F_EMPLOYEE_FULLNAME]; GO
IF OBJECT_ID('dbo.F_EMPLOYEE_GET', 'FN') IS NOT NULL DROP FUNCTION [dbo].[F_EMPLOYEE_GET]; GO

-- Создание новой версии F_WORKS_LIST (ITVF)
CREATE FUNCTION [dbo].[F_WORKS_LIST]()
RETURNS TABLE
AS
RETURN
(
    SELECT
        W.Id_Work,
        W.CREATE_Date,
        W.MaterialNumber,
        W.IS_Complit,
        W.FIO,
        CONVERT(VARCHAR(10), W.CREATE_Date, 104) AS D_DATE,
        ISNULL(SUM(CASE WHEN WI.Is_Complit = 0 AND A.IS_GROUP = 0 THEN 1 ELSE 0 END), 0) AS WorkItemsNotComplit,
        ISNULL(SUM(CASE WHEN WI.Is_Complit = 1 AND A.IS_GROUP = 0 THEN 1 ELSE 0 END), 0) AS WorkItemsComplit,
        ISNULL(
            RTRIM(REPLACE(E.SURNAME + ' ' + UPPER(SUBSTRING(E.NAME, 1, 1)) + '. ' + UPPER(SUBSTRING(E.PATRONYMIC, 1, 1)) + '.', '. .', '')),
            E.LOGIN_NAME
        ) AS EmployeeFullName,
        W.StatusId,
        WS.StatusName,
        CASE
            WHEN (W.Print_Date IS NOT NULL) OR
                 (W.SendToClientDate IS NOT NULL) OR
                 (W.SendToDoctorDate IS NOT NULL) OR
                 (W.SendToOrgDate IS NOT NULL) OR
                 (W.SendToFax IS NOT NULL)
            THEN 1
            ELSE 0
        END AS Is_Print
    FROM
        Works AS W
    LEFT OUTER JOIN WorkStatus AS WS ON W.StatusId = WS.StatusID
    LEFT OUTER JOIN Employee AS E ON W.Id_Employee = E.Id_Employee
    LEFT OUTER JOIN WorkItem AS WI ON W.Id_Work = WI.Id_Work
    LEFT OUTER JOIN Analiz AS A ON WI.ID_ANALIZ = A.ID_ANALIZ
    WHERE
        W.IS_DEL <> 1
    GROUP BY
        W.Id_Work, W.CREATE_Date, W.MaterialNumber, W.IS_Complit, W.FIO, W.StatusId,
        WS.StatusName, E.SURNAME, E.NAME, E.PATRONYMIC, E.LOGIN_NAME,
        W.Print_Date, W.SendToClientDate, W.SendToDoctorDate, W.SendToOrgDate, W.SendToFax
)
```
## Результаты первой оптимизации:
- **CPU time** = 2110 мс (около 2.1 секунды)
- **elapsed time** = 130228 мс (около 130 секунд)
- **Логические чтения**:
  - Table 'Analiz': Scan count 8, logical reads 584652
  - Table 'Employee': Scan count 4, logical reads 19810
  - Table 'WorkItem': Scan count 10, logical reads 2724

## Вторая оптимизация: Добавление некластеризованных индексов
**Внесенные изменения**:
1. `IX_WorkItem_WorkId_IsComplit_AnalizId` на `dbo.WorkItem (Id_Work, Is_Complit, ID_ANALIZ)`
2. `IX_Analiz_IsGroup_AnalizId` на `dbo.Analiz (IS_GROUP, ID_ANALIZ)`
3. `IX_Works_IsDel` на `dbo.Works (IS_DEL)`

```sql
-- Создание индексов
CREATE NONCLUSTERED INDEX IX_WorkItem_WorkId_IsComplit_AnalizId
ON dbo.WorkItem (Id_Work, Is_Complit, ID_ANALIZ);
GO

CREATE NONCLUSTERED INDEX IX_Analiz_IsGroup_AnalizId
ON dbo.Analiz (IS_GROUP, ID_ANALIZ);
GO

CREATE NONCLUSTERED INDEX IX_Works_IsDel
ON dbo.Works (IS_DEL);
GO
```
## Результаты второй оптимизации

**CPU time** = 968 мс (около 0.97 секунды)  
**elapsed time** = 971 мс (около 0.97 секунды)  

**Логические чтения**:  
- Table 'WorkItem':  
  - Scan count 2  
  - logical reads 1146 (Снижение на ~58%)  
- Table 'Analiz':  
  - Scan count 2  
  - logical reads 4 (Массовое снижение на ~99.99%)  
- Table 'Employee':  
  - Scan count 2  
  - logical reads 4 (Массовое снижение на ~99.98%)  
- Table 'Works':  
  - Scan count 2  
  - logical reads 219  

## Заключение по Задаче 2-го уровня

Цель по производительности была успешно достигнута без изменения структуры таблиц. Сочетание:

1. **Рефакторинга функции F_WORKS_LIST** во встроенную табличную функцию  
2. **Стратегического добавления** некластеризованных индексов  

позволило сократить время выполнения для получения 3000 заказов:  
- **С было**: 39 секунд  
- **Стало**: ~1 секунда  

## Задача 3-го уровня: Недостатки структурных изменений

**Потенциальные проблемы**:  

- 📈 **Увеличение сложности** и затрат на обслуживание  
- ✍️ **Влияние на операции записи** (INSERT/UPDATE/DELETE)  
- 💾 **Увеличение объема** хранимых данных  
- ⚠️ **Риск несогласованности** данных  
- 🔄 **Зависимость от СУБД** и переносимость  

### Вывод  

**Добавление индексов и рефакторинг функций** часто предпочтительнее, поскольку они:  

- ✅ **Улучшают производительность** чтения  
- ❌ **Не имеют существенных недостатков** глубоких структурных изменений  
