CREATE TABLE [dbo].[Udc_Dettaglio]
(
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL,
[Matricola] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [DF_Saldi_Dettaglio_MATR] DEFAULT ('00000000000000000000'),
[Data_Creazione] [datetime] NOT NULL CONSTRAINT [DF_Saldi_Dettaglio_DT_CRE] DEFAULT (getdate()),
[Data_Lotto] [datetime] NULL,
[Data_Scadenza] [datetime] NULL,
[Lotto] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Utente_Movimento] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Id_Tipo_Causale_Movimento] [int] NULL,
[Id_Lista] [int] NULL,
[Id_Dettaglio] [int] NULL,
[Quantita_Pezzi] [numeric] (18, 4) NOT NULL CONSTRAINT [DF_Saldi_Dettaglio_QT_PEZZI] DEFAULT ((0)),
[Id_Contenitore] [varchar] (5) COLLATE Latin1_General_CI_AS NULL,
[Posizione_X] [int] NULL CONSTRAINT [DF_Saldi_Dettaglio_OCCU_X] DEFAULT ((0)),
[Posizione_Y] [int] NULL CONSTRAINT [DF_Saldi_Dettaglio_OCCU_Y] DEFAULT ((0)),
[Qta_Persistenza] [numeric] (18, 4) NULL,
[Note] [varchar] (500) COLLATE Latin1_General_CI_AS NULL,
[Xml_Param] [xml] NULL,
[Id_UdcDettaglio] [int] NOT NULL IDENTITY(1, 1),
[Id_UdcContainer] [int] NULL,
[Id_Ddt_Reale] [int] NULL,
[Id_Riga_Ddt] [int] NULL,
[Id_Testata_Lista_Prelievo] [int] NULL,
[Id_Riga_Lista_Prelievo] [int] NULL,
[Id_Causale_L3] [varchar] (4) COLLATE Latin1_General_CI_AS NULL,
[WBS_Riferimento] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[Control_Lot] [varchar] (40) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[Insert_Movimenti_ContCaric]
   ON  [dbo].[Udc_Dettaglio]
   FOR UPDATE,INSERT,DELETE
AS 
BEGIN
	DECLARE @Errore				VARCHAR(130)
	DECLARE @Qta				NUMERIC(18, 4)
	DECLARE @Return				INT
	DECLARE @Id_Udc				INT
	DECLARE @Id_Articolo		INT
	DECLARE @Lotto				VARCHAR(20)
	DECLARE @Id_Utente			VARCHAR(16) 
	DECLARE @Id_Tipo_Causale	INT
	DECLARE @Quantita_Pezzi		NUMERIC(18,4)
	DECLARE @Qta_Persistenza	NUMERIC(18,4)
	DECLARE @Id_Lista			INT
	DECLARE @Id_Dettaglio		INT
	DECLARE @Codice_Lista		Varchar(30)
	DECLARE @Codice_Riga		Varchar(7)
	DECLARE @DtLotto			DATETIME
	DECLARE @DtScadenza			DATETIME

	DECLARE Cur_Movimenti CURSOR LOCAL STATIC FOR
		SELECT	Id_Udc,
				Id_Articolo,
				Lotto,
				Id_Utente_Movimento,
				Quantita_Pezzi,
				Qta_Persistenza,
				Data_Lotto,
				Data_Scadenza
		FROM	DELETED

	OPEN Cur_Movimenti
	FETCH NEXT FROM Cur_Movimenti INTO
			@Id_Udc,
			@Id_Articolo,
			@Lotto,
			@Id_Utente,
			@Quantita_Pezzi,
			@Qta_Persistenza,
			@DtLotto,
			@DtScadenza

	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Entro solo se la Qta che sto eliminando è maggiore di 0 altrimenti mi va in Loop (pulizia del trigger.)
		IF @Quantita_Pezzi <> 0
				AND
			NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	INSERTED
							WHERE	Id_Udc = @Id_Udc
								AND Id_Articolo = @Id_Articolo
								AND Lotto = @Lotto
						)
		BEGIN
			-- e' un Item_Empty, quindi tolgo tutte le quantita
			EXEC @Return = sp_Insert_Movimenti
					@Id_Udc,
					@Id_Articolo,
					@Lotto,
					@Quantita_Pezzi,
					6,
					NULL,
					NULL,
					@DtLotto,
					@DtScadenza,
					'tr_Insert_Movimenti',
					sp_Insert_Movimenti,
					@Id_Utente,
					@Errore	OUTPUT

			IF @Return = 1
				RAISERROR(@Errore,12,1)

			DELETE	Missioni_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
		END

		ELSE IF @Quantita_Pezzi = 0
					AND
				NOT EXISTS	(
								SELECT	TOP 1 1
								FROM	INSERTED
								WHERE	Id_Udc = @Id_Udc
									AND Id_Articolo = @Id_Articolo
									AND Lotto = @Lotto
							)
			SELECT 'CONTROLLARE'
		ELSE
		BEGIN
			--Recupero la causale del movimento per sapere come calcolare la qta movimentata;
			SELECT	@Id_Tipo_Causale = Id_Tipo_Causale_Movimento,
					@Id_Utente = Id_Utente_Movimento,
					@Id_Lista = Id_Lista,
					@Id_Dettaglio = Id_Dettaglio
			FROM	INSERTED
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
				AND Lotto = @Lotto

			IF @Id_Tipo_causale IS NULL
			BEGIN
				SET @Errore = 'Causale del movimento non specificata'
				RAISERROR(@Errore,12,1)
			END
			
			DECLARE @QTA_Inserita		NUMERIC(18,4)
			SELECT	@QTA_Inserita = SUM(Quantita_Pezzi)
			FROM	INSERTED
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
				AND Lotto = @Lotto

			IF	ISNULL(@QTA_Inserita,0) <> ISNULL(@Quantita_Pezzi,0)
			BEGIN
				IF @Id_Tipo_Causale IN (1,2,9)
				BEGIN
					SET @Qta = @Quantita_Pezzi - @QTA_Inserita

					EXEC @Return = sp_Insert_Movimenti
							@Id_Udc,
							@Id_Articolo,
							@Lotto,
							@Qta,
							@Id_Tipo_Causale,
							@Codice_Lista,
							@Codice_Riga,
							@DtLotto,
							@DtScadenza,
							'tr_Insert_Movimenti',
							sp_Insert_Movimenti,
							@Id_Utente,
							@Errore	OUTPUT

					IF @Return = 1
						RAISERROR(@Errore,12,1)

					-- Se la Qta_Persistenza è <> da Null non cancello la referenza.
					IF	@Qta_Persistenza IS NULL
							AND
						ISNULL(@QTA_Inserita,0) = 0
						-- Se non sono rimasti pezzi cancello dalla udc il riferimento all'articolo.
						DELETE	Udc_Dettaglio
						WHERE	Id_Udc = @Id_Udc
							AND Id_Articolo = @Id_Articolo
							AND Lotto = @Lotto
				END
				ELSE IF @Id_Tipo_Causale IN (3,8,7)
				BEGIN
					SET @Qta = ISNULL(@QTA_Inserita,0) - ISNULL(@Quantita_Pezzi,0)

					EXEC @Return = sp_Insert_Movimenti
							@Id_Udc,
							@Id_Articolo,
							@Lotto,
							@Qta,
							@Id_Tipo_Causale,
							@Codice_Lista,
							@Codice_Riga,
							@DtLotto,
							@DtScadenza,
							'tr_Insert_Movimenti',
							sp_Insert_Movimenti,
							@Id_Utente,
							@Errore			OUTPUT

					IF @Return = 1
						RAISERROR(@Errore,12,1)
				END
				ELSE IF @Id_Tipo_Causale = 5
				BEGIN
					SELECT	@Qta = ISNULL(SUM(I.Quantita_Pezzi),0) - ISNULL(SUM(D.Quantita_Pezzi),0)
					FROM	INSERTED		I
					JOIN	DELETED			D
					ON		D.Id_Udc = I.Id_Udc
						AND D.Id_Articolo = I.Id_Articolo
						AND D.Lotto = I.Lotto
					WHERE	I.Id_Udc = @Id_Udc
						AND I.Id_Articolo = @Id_Articolo
						AND I.Lotto = @Lotto

					IF @Qta <> 0
					BEGIN
						EXEC @Return = sp_Insert_Movimenti
								@Id_Udc,
								@Id_Articolo,
								@Lotto,
								@Qta,
								@Id_Tipo_Causale,
								NULL,
								NULL,
								@DtLotto,
								@DtScadenza,
								'tr_Insert_Movimenti',
								sp_Insert_Movimenti,
								@Id_Utente,
								@Errore		OUTPUT

						IF @Return = 1
							RAISERROR(@Errore,12,1)
					END

					-- Se la Qta_Persistenza è <> da Null non cancello la referenza.
					IF	@Qta_Persistenza IS NULL
							AND
						ISNULL(@QTA_Inserita,0) = 0
						-- Se non sono rimasti pezzi cancello dalla udc il riferimento all'articolo.
						DELETE	Udc_Dettaglio
						WHERE	Id_Udc = @Id_Udc
							AND Id_Articolo = @Id_Articolo
							AND Lotto = @Lotto
				END
			END
		END

		SET @Id_Tipo_Causale = NULL

		FETCH NEXT FROM Cur_Movimenti INTO
			@Id_Udc,
			@Id_Articolo,
			@Lotto,
			@Id_Utente,
			@Quantita_Pezzi,
			@Qta_Persistenza,
			@DtLotto,
			@DtScadenza
	END

	CLOSE Cur_Movimenti
	DEALLOCATE Cur_Movimenti

	-- Ora eseguo il ciclo per gli inserimenti nuovi
	IF EXISTS	(
					SELECT	Id_Udc,
							Id_Articolo,
							Lotto
					FROM	INSERTED
					EXCEPT	
					SELECT	Id_Udc,
							Id_Articolo,
							Lotto
					FROM DELETED
				)
	BEGIN
		DECLARE Cur_Movimenti CURSOR FOR
			SELECT	Id_Udc,
					Id_Articolo,
					Lotto,
					Data_Lotto,
					Data_Scadenza
			FROM	INSERTED
			EXCEPT	
			SELECT	Id_Udc,
					Id_Articolo,
					Lotto,
					Data_Lotto,
					Data_Scadenza
			FROM	DELETED

		OPEN Cur_Movimenti
		FETCH NEXT FROM Cur_Movimenti INTO
			@Id_Udc,
			@Id_Articolo,
			@Lotto,
			@DtLotto,
			@DtScadenza

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT	@Id_Utente = Id_Utente_Movimento,
					@Id_Tipo_Causale = Id_Tipo_Causale_Movimento,
					@Id_Lista = Id_Lista,
					@Id_Dettaglio = Id_Dettaglio
			FROM	Udc_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
				AND Lotto = @Lotto

			SELECT	@Quantita_Pezzi = Quantita_Pezzi
			FROM	INSERTED
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
				AND Lotto = @Lotto

			EXEC @Return = sp_Insert_Movimenti
					@Id_Udc,
					@Id_Articolo,
					@Lotto,
					@Quantita_Pezzi,
					@Id_Tipo_Causale,
					@Codice_Lista,
					@Codice_Riga,
					@DtLotto,
					@DtScadenza,
					'tr_Insert_Movimenti',
					sp_Insert_Movimenti,
					@Id_Utente,
					@Errore		OUTPUT

			IF @Return = 1
				RAISERROR(@Errore,12,1)

			FETCH NEXT FROM Cur_Movimenti INTO
				@Id_Udc,
				@Id_Articolo,
				@Lotto,
				@DtLotto,
				@DtScadenza
		END

		CLOSE Cur_Movimenti
		DEALLOCATE Cur_Movimenti
	END
END
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [CK_Udc_Dettaglio] CHECK (([Quantita_Pezzi]>=(0)))
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [PK__Udc_Dett__A000DB8866B4C6D1] PRIMARY KEY CLUSTERED ([Id_UdcDettaglio]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Udc_Dettaglio] ON [dbo].[Udc_Dettaglio] ([Id_Udc], [Id_Articolo], [Lotto], [WBS_Riferimento]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [Udc_Articolo_Lotto_Univoci] UNIQUE NONCLUSTERED ([Id_Udc], [Id_Articolo], [Lotto], [WBS_Riferimento]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [FK__Udc_Detta__Id_Ud__4D2051A6] FOREIGN KEY ([Id_UdcContainer]) REFERENCES [Compartment].[UdcContainer] ([Id_UdcContainer])
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [FK_Udc_Dettaglio_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [FK_Udc_Dettaglio_Tipo_Causali_Movimenti] FOREIGN KEY ([Id_Tipo_Causale_Movimento]) REFERENCES [dbo].[Tipo_Causali_Movimenti] ([Id_Tipo_Causale])
GO
ALTER TABLE [dbo].[Udc_Dettaglio] ADD CONSTRAINT [FK_Udc_Dettaglio_Udc_Testata] FOREIGN KEY ([Id_Udc]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc])
GO
EXEC sp_addextendedproperty N'MS_Description', N'SQLero 05/05/2003 colonna aggiunta x ordinare i saldi x anzianità nel trova articolo ', 'SCHEMA', N'dbo', 'TABLE', N'Udc_Dettaglio', 'COLUMN', N'Data_Creazione'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Ultimo Utente che ha effettuato il movimento sul dettaglio.(Mi serve per recuperarlo nel trigger che scrive il movimento).', 'SCHEMA', N'dbo', 'TABLE', N'Udc_Dettaglio', 'COLUMN', N'Id_Tipo_Causale_Movimento'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Campo ke indica la persistenza dell''articolo se è a zero;la persistenza e la qta massima caricabile d quell''articolo se è maggiore di zero;neinte se è a null.', 'SCHEMA', N'dbo', 'TABLE', N'Udc_Dettaglio', 'COLUMN', N'Qta_Persistenza'
GO
