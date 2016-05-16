require 'bankscrap'
require 'securerandom'

module Bankscrap
  module BBVANetCash
    class Bank < ::Bankscrap::Bank

      BASE_ENDPOINT         = 'https://www.bbvanetcash.mobi'.freeze
      LOGIN_ENDPOINT        = '/DFAUTH/slod_mult_mult/EAILServlet'.freeze
      ACCOUNTS_ENDPOINT     = '/SESKYOS/kyos_mult_web_servicios_02/services/rest/CuentasServiceREST/getDatosCuentas'.freeze
      TRANSACTIONS_ENDPOINT = '/SESKYOS/kyos_mult_web_servicios_02/services/rest/CuentasServiceREST/getMovimientos'.freeze

      def initialize(user, password, log: false, debug: false, extra_args: nil)
        @company_code = extra_args.with_indifferent_access['company_code']
        @user = format_user(user.dup, @company_code.to_s.dup)
        @password = password.upcase
        @log = log
        @debug = debug

        initialize_connection

        # Create a user_agent with a random string for privacy
        user_agent = SecureRandom.hex(32).upcase + ';Android;LGE;Nexus 5;1080x1776;Android;5.1.1;BMES;4.4;xxhd'

        add_headers(
          'User-Agent'       => user_agent,
          'Accept'           => 'application/json',
          'Accept-Charset'   => 'UTF-8',
          'Connection'       => 'Keep-Alive',
          'Host'             => 'www.bbvanetcash.mobi'
        )

        login
        super
      end

      # Fetch all the accounts for the given user
      # Returns an array of Bankscrap::Account objects
      def fetch_accounts
        log 'fetch_accounts'

        custom_headers = {
          'Content-Type' => 'application/json; charset=UTF-8',
          'Contexto' => get_context
        }

        params = {
          "peticionCuentasKYOSPaginadas" =>  {
            "favoritos" => false,
            "paginacion" => "0"
          }
        }

        response = with_headers(custom_headers) do
          post(BASE_ENDPOINT + ACCOUNTS_ENDPOINT, fields: params.to_json)
        end

        json = JSON.parse(response)

        if json['respuestacuentas']['cuentas'].is_a? Array
          # TODO: test this with a user with multiple accounts
          json['respuestacuentas']['cuentas'].map { |data| build_account(data) }
        else
          [build_account(json['respuestacuentas']['cuentas'])]
        end
      end

      # Fetch transactions for the given account.
      # By default it fetches transactions for the last month,
      # The maximum allowed by the BBVA API is the last 3 years.
      #
      # Account should be a Bankscrap::Account object
      # Returns an array of Bankscrap::Transaction objects
      def fetch_transactions_for(account, start_date: Date.today - 1.month, end_date: Date.today)
        from_date = start_date.strftime('%Y-%m-%d')

        custom_headers = {
          'Content-Type' => 'application/json; charset=UTF-8',
          'Contexto' => get_context
        }

        params = {
          "peticionMovimientosKYOS" => {
            "numAsunto" => account.iban,
            "bancoAsunto" => "BANCO BILBAO VIZCAYA ARGENTARIA S.A",
            "fechaDesde" => start_date.strftime("%Y%m%d"),
            "fechaHasta" => end_date.strftime("%Y%m%d"),
            "concepto" => [],
            "importe_Desde" => "",
            "importe_Hasta" => "",
            "divisa" => "EUR",
            "paginacionTLSMT017" => "N000000000000+0000000000000000000",
            "paginacionTLSMT016" => "N00000000000+0000000000000000",
            "descargaInformes" => false,
            "numElem" => 0,
            "banco" => "1",
            "idioma" => "51",
            "formatoFecha" => "dd\/MM\/yyyy",
            "paginacionMOVDIA" => "1",
            "ultimaFechaPaginacionAnterior" => "",
            "ordenacion" => "DESC"
          }
        }

        url = BASE_ENDPOINT + TRANSACTIONS_ENDPOINT

        transactions = []
        with_headers(custom_headers) do
          # Loop over pagination
          loop do
            json = JSON.parse(post(url, fields: params.to_json))['respuestamovimientos']

            if json['movimientos'].is_a?(Array)
              unless json['movimientos'].blank?
                transactions += json['movimientos'].map do |data|
                  build_transaction(data, account)
                end
                
                params['peticionMovimientosKYOS']['paginacionMOVDIA'] = json['paginacionMOVDIA']
                params['peticionMovimientosKYOS']['paginacionTLSMT016'] = json['paginacionTLSMT016']
                params['peticionMovimientosKYOS']['paginacionTLSMT017'] = json['paginacionTLSMT017']
              end
              break unless (json['descripcion'] == 'More records available')
            elsif json['movimientos'].is_a?(Hash)
              # There was only 1 transaction for this query
              transactions << build_transaction(json['movimientos'], account)
              break
            else
              # No transactions
              break
            end
          end
        end

        transactions
      end

      private

      # The user that gets sent to the API is a string composed by 3 items:
      # 00230001 <- no idea why this number ¯\_(ツ)_/¯
      # Company code
      # User <- always in upcase
      def format_user(user, company_code)
        '00230001' + company_code + user.upcase
      end

      def login
        log 'login'
        params = {
          'origen'         => 'pibeemovil',
          'eai_tipoCP'     => 'up',
          'eai_URLDestino' => 'success_eail_CAS.jsp',
          'eai_user'       => @user,
          'eai_password'   => @password
        }
        post(BASE_ENDPOINT + LOGIN_ENDPOINT, fields: params)
      end

      # Build an Account object from API data
      def build_account(data)
        Account.new(
          bank: self,
          id: data['referencia'],
          name: data['empresaDes'],
          available_balance: data['saldoValor'].to_f,
          balance: data['saldoContable'],
          currency: data['divisa'],
          iban: data['numeroAsunto'],
          description: "#{data['bancoDes']} #{data['numeroAsuntoMostrar']}"
        )
      end

      # Build a transaction object from API data
      def build_transaction(data, account)
        Transaction.new(
          account: account,
          id: data['codRmsoperS'],
          amount: transaction_amount(data),
          description: data['concepto'] || data['descConceptoTx'],
          effective_date: Date.strptime(data['fechaContable'], '%d/%m/%Y'),
          currency: data['divisa'],
          balance: Money.new(data['saldoContable'].to_f * 100, data['currency'])
        )
      end

      def transaction_amount(data)
        Money.new(data['importe'].to_f * 100, data['divisa'])
      end

      # This API has a custom header called 'Contexto' that is required for every
      # request after login. Some of the data has been anonymized.
      def get_context
        {
          "perfil" => {
            "usuario" => @user,
            "nombre" => "",
            "apellido1" => "",
            "apellido2" => "",
            "dni" => "",
            "cargoFun" => "",
            "centroCoste" => "",
            "matricula" => "",
            "bancoOperativo" => "",
            "oficinaOperativa" => "",
            "bancoFisico" => "",
            "oficinaFisica" => "",
            "paisOficina" => "",
            "idioma" => "1",
            "idiomaIso" => "1",
            "divisaBase" => "ZZZ",
            "divisaSecundaria" => "",
            "xtiOfiFisica" => "",
            "xtiOfiOperati" => "",
            "listaAutorizaciones" => [
              "AAAA",
              "BBBB"
            ]
          },
          "puesto" => {
            "puestoLogico" => "3"
          },
          "transacciones" => {
            "canalLlamante" => "4",
            "medioAcceso" => "7",
            "secuencia" => nil,
            "servicioProducto" => "27",
            "tipoIdentificacionCliente" => "6",
            "identificacionCliente" => "",
            "modoProceso" => nil,
            "autorizacion" => nil,
            "origenFisico" => nil
          },
          "datosTecnicos" => {
            "idPeticion" => nil,
            "UUAARemitente" => nil,
            "usuarioLogico" => "",
            "cabecerasHttp" => {
              "aap" => "00000034",
              "iv-user" => @user
            }
          },
          "codigoCliente" => "1",
          "tipoAutenticacion" => "1",
          "identificacionCliente" => "",
          "tipoIdentificacionCliente" => "6",
          "propiedades" => nil
        }
      end
    end
  end
end
