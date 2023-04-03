SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Author,,Marco Fara>
-- Create date: <Create 17 10 2006, ,>
-- Description:	<converte il numero di partizione in ASI >
-- =============================================
create FUNCTION [dbo].[isEmptyPartizione]
	(@Id_Partizione INT)
RETURNS bit
AS
BEGIN 
	return  (select	case count(0)
				when 0 then 1
				else 0
			end
	 from	Udc_Posizione
	 where	Id_Partizione = @Id_Partizione)
END





GO
