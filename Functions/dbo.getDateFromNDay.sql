SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[getDateFromNDay]
(
	@Lotto VARCHAR(20)
)
RETURNS DATE
AS
BEGIN
	DECLARE @Anno INT;
	DECLARE @NumeroGiorni INT;
	DECLARE @b INT; 
	DECLARE @c INT;
	DECLARE @e INT;
	DECLARE @m INT;
	DECLARE @d INT;
	DECLARE @fReturn DATE;

	SET @Anno = LEFT(@Lotto, 2) + 2000;
	SET @NumeroGiorni = SUBSTRING(@Lotto, 3, 3);


	IF (((@Anno % 4) != 0) OR (((@Anno % 100) = 0) AND ((@Anno % 400) != 0)))
	BEGIN
		SET @b = FLOOR((@NumeroGiorni + 1889 - 122.1) / 365.25);
		SET @c = @NumeroGiorni + 1889 - FLOOR(365.25 * @b);
		SET @e = FLOOR (@c / 30.6001);
		IF (@e < 13.5)
		BEGIN
			SET @m = @e - 1;
		END
		ELSE
			IF (@e > 13.5)
			BEGIN
				SET @m = @e - 13;
			END;
		SET @d = @c - FLOOR(30.6001 * @e);
	END;

	IF ((((@Anno % 4) = 0) AND (NOT (((@Anno % 100) = 0) AND ((@Anno % 400) != 0)))))
	BEGIN
		SET @b = FLOOR ((@NumeroGiorni + 1523 - 122.1) / 365.25);
		SET @c = @NumeroGiorni + 1523 - FLOOR (365.25 * @b);
		SET @e = FLOOR (@c / 30.6001);
		IF (@e < 13.5) 
		BEGIN
			SET @m = @e - 1;
		END
		ELSE
			IF (@e > 13.5)
			BEGIN
				SET @m = @e - 13;
			END
		SET @d = @c - FLOOR (30.6001 * @e);
	END;
	SET @fReturn = DATEFROMPARTS(@Anno, @m, @d);
	RETURN @fReturn;
END
GO
