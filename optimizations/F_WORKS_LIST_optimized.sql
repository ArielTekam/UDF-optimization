CREATE FUNCTION [dbo].[F_WORKS_LIST]
(
)
RETURNS TABLE -- Изменение типа функции: с многооператорной на встроенную табличную функцию (ITVF)
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
        -- Прямой расчет WorkItemsNotComplit
        (
            SELECT COUNT(WI_NC.ID_WORKItem)
            FROM WorkItem AS WI_NC
            WHERE WI_NC.Id_Work = W.Id_Work
            AND WI_NC.Is_Complit = 0
            -- Исключить группы, если необходимо, согласно логике F_WORKITEMS_COUNT_BY_ID_WORK
            AND WI_NC.ID_ANALIZ NOT IN (SELECT ID_ANALIZ FROM Analiz WHERE IS_GROUP = 1)
        ) AS WorkItemsNotComplit,
        -- Прямой расчет WorkItemsComplit
        (
            SELECT COUNT(WI_C.ID_WORKItem)
            FROM WorkItem AS WI_C
            WHERE WI_C.Id_Work = W.Id_Work
            AND WI_C.Is_Complit = 1
            -- Исключить группы, если необходимо
            AND WI_C.ID_ANALIZ NOT IN (SELECT ID_ANALIZ FROM Analiz WHERE IS_GROUP = 1)
        ) AS WorkItemsComplit,
        -- Формирование полного имени сотрудника напрямую через JOIN
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
    LEFT OUTER JOIN
        WorkStatus AS WS ON W.StatusId = WS.StatusID
    LEFT OUTER JOIN
        Employee AS E ON W.Id_Employee = E.Id_Employee -- Соединение для получения информации о сотруднике
    WHERE
        W.IS_DEL <> 1
)