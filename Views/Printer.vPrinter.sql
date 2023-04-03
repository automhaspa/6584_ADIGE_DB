SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [Printer].[vPrinter] AS
	SELECT	CONCAT(SUBSTRING(PART.DESCRIZIONE,1,4), ' - ', P.Name)		Stampante,
			P.Name,
			PA.Id_Partizione,
			P.Id_Printer
	FROM	Printer.Printer					P
	JOIN	Printer.Printer_Association		PA
	ON		PA.Id_Printer = P.Id_Printer
	JOIN	Partizioni						PART
	ON		PART.ID_PARTIZIONE = PA.Id_Partizione

GO
