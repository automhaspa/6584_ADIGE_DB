SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[missioniProgress]
	(@Id_Missione INT)
RETURNS int
AS
BEGIN
	return isnull((select top 1 100 * count(case Id_Tipo_Stato_Percorso when 3 then Id_Tipo_Stato_Percorso else null end) over (partition by id_percorso) / count(0) over (partition by id_percorso) from Percorso where Id_Percorso = @Id_Missione),0)
END



GO
