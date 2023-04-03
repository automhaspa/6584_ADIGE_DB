CREATE TABLE [dbo].[fnTempo]
(
[Id_Partizione_Baia] [int] NOT NULL,
[Id_Partizione_Magazzino] [int] NOT NULL,
[Priorita] [int] NULL,
[Flag_Attivo] [bit] NOT NULL,
[Direction] [varchar] (1) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fnTempo] ADD CONSTRAINT [PK_fnTempo] PRIMARY KEY CLUSTERED ([Id_Partizione_Baia], [Id_Partizione_Magazzino]) ON [PRIMARY]
GO
