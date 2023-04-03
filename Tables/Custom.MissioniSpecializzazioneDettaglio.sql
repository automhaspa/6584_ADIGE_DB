CREATE TABLE [Custom].[MissioniSpecializzazioneDettaglio]
(
[Id_Ddt_Fittizio] [int] NOT NULL,
[Id_Udc] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NOT NULL,
[N_Uscite] [int] NOT NULL CONSTRAINT [DF_MissioniSpecializzazioneDettaglio_N_Uscite] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[MissioniSpecializzazioneDettaglio] ADD CONSTRAINT [PK__Missioni__16FFB605E6158144] PRIMARY KEY CLUSTERED ([Id_Ddt_Fittizio], [Id_Udc]) ON [PRIMARY]
GO
