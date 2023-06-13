SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [Printer].[vPrinter] AS
	SELECT	CASE
				WHEN P.Id_Printer = 11 THEN CONCAT('ADIGE 1 - ',P.Name)
				ELSE CONCAT(SUBSTRING(PART.DESCRIZIONE,1,4), ' - ', P.Name)		
			END				Stampante,
			P.Id_Printer
	FROM	Printer.Printer					P
	JOIN	Printer.Printer_Association		PA
	ON		PA.Id_Printer = P.Id_Printer
	JOIN	Partizioni						PART
	ON		PART.ID_PARTIZIONE = PA.Id_Partizione

GO
