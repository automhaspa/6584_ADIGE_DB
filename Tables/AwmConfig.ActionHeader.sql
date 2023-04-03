CREATE TABLE [AwmConfig].[ActionHeader]
(
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[ProcedureKey] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ProcedureName] [nvarchar] (200) COLLATE Latin1_General_CI_AS NOT NULL,
[CSS] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[DisplayOrder] [int] NULL,
[ConfResource] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[IsWebService] [bit] NOT NULL CONSTRAINT [DF_ActionHeader_IsWebService] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeader] ADD CONSTRAINT [PK_ActionHeader] PRIMARY KEY CLUSTERED ([hash], [ProcedureKey]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeader] ADD CONSTRAINT [FK_ActionHeader_Routes] FOREIGN KEY ([hash]) REFERENCES [AwmConfig].[Routes] ([hash]) ON DELETE CASCADE ON UPDATE CASCADE
GO
