CREATE TABLE [dbo].[Lista_Uscita_Testata]
(
[Id_Lista] [int] NOT NULL,
[Data_Consegna] [datetime] NULL,
[Id_Cliente] [int] NOT NULL,
[Note_Associate] [varchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Indicativo] [int] NULL,
[Gruppo_Udc] [int] NULL,
[Id_Tipo_Lista] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[Filler] [sql_variant] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lista_Uscita_Testata] ADD CONSTRAINT [PK_Lista_Uscita_Testata] PRIMARY KEY CLUSTERED ([Id_Lista]) ON [PRIMARY]
GO
