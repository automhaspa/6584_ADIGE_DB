CREATE TABLE [dbo].[Partizioni]
(
[ID_SOTTOCOMPONENTE] [int] NOT NULL,
[ID_PARTIZIONE] [int] NOT NULL IDENTITY(6000, 1),
[DESCRIZIONE] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[CODICE_ABBREVIATO] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL,
[ID_TIPO_PARTIZIONE] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[CAPIENZA] [int] NOT NULL,
[LOCKED] [bit] NULL CONSTRAINT [DF_Partizioni_Locked] DEFAULT ((0)),
[VUOTA] AS ([dbo].[isEmptyPartizione]([Id_Partizione])),
[ALTEZZA] [int] NOT NULL CONSTRAINT [DF_Partizioni_Altezza] DEFAULT ((0)),
[LARGHEZZA] [int] NOT NULL CONSTRAINT [DF_Partizioni_Larghezza] DEFAULT ((0)),
[PROFONDITA] [int] NOT NULL CONSTRAINT [DF_Partizioni_Profondita] DEFAULT ((0)),
[PESO] [int] NOT NULL CONSTRAINT [DF_Partizioni_Peso] DEFAULT ((0)),
[Motivo_Blocco] [varchar] (max) COLLATE Latin1_General_CI_AS NULL CONSTRAINT [DF__Partizion__Motiv__174E50DA] DEFAULT ('')
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Partizioni] ADD CONSTRAINT [PK_Partizioni_1] PRIMARY KEY CLUSTERED ([ID_PARTIZIONE]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Partizioni_1] ON [dbo].[Partizioni] ([ID_SOTTOCOMPONENTE], [CODICE_ABBREVIATO]) ON [PRIMARY]
GO
