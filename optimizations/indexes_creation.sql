-- Index sur WorkItem pour les agrégations
CREATE NONCLUSTERED INDEX IX_WorkItem_WorkId_IsComplit_AnalizId
ON dbo.WorkItem (Id_Work, Is_Complit, ID_ANALIZ);
GO

-- Index sur Analiz pour la condition IS_GROUP
CREATE NONCLUSTERED INDEX IX_Analiz_IsGroup_AnalizId
ON dbo.Analiz (IS_GROUP, ID_ANALIZ);
GO

-- Index sur Works pour le filtre IS_DEL
CREATE NONCLUSTERED INDEX IX_Works_IsDel
ON dbo.Works (IS_DEL);
GO