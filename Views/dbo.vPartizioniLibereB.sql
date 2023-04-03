SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create view [dbo].[vPartizioniLibereB] as
SELECT * FROM Partizioni pp WHERE ID_SOTTOCOMPONENTE NOT IN (
			SELECT p.ID_SOTTOCOMPONENTE FROM Partizioni p 
			LEFT JOIN Udc_Posizione up ON up.Id_Partizione = p.ID_PARTIZIONE
			LEFT JOIN Udc_Testata ut ON ut.Id_Udc = up.Id_Udc
			WHERE p.ID_TIPO_PARTIZIONE = 'MA' AND ut.Id_Udc IS NOT NULL AND ut.Id_Tipo_Udc NOT IN (4,5,6))
			AND pp.ID_TIPO_PARTIZIONE = 'MA'
GO
