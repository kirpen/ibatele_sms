# encoding: utf-8
require 'net/http'
require 'timeout'

module IbateleSms

  module Base

    extend self

    def sessionid(user, password)

      data  = ""
      pr    = ::URI.encode_www_form({

        login:      user,
        password:   password

      })

      err = block_run do |http|

        log("[sessionid] => /rest/User/SessionId?#{pr}")

        res  = http.get("/rest/User/SessionId?#{pr}")
        data = ::JSON.parse(res.body) rescue (res.body || "").gsub('"', '')

        log("[sessionid] <= #{data}")

      end # block_run

      return err  if err
      return data unless data.is_a?(::Hash)

      case data["Code"]

        when 1 then ::IbateleSms::AuthError.new(data["Desc"])
        when 4 then ::IbateleSms::AuthError.new(data["Desc"])
        else        ::IbateleSms::UnknownError.new(data["Desc"])

      end # case

    end # sessionid

    def sms_send(sid, phone, msg, ttl = 48*60)

      data  = ""
      pr    = ::URI.encode_www_form({

        sessionId:          sid,
        data:               msg,
        validity:           ttl,
        destinationAddress: phone,
        sourceAddress:      ::IbateleSms::TITLE_SMS

      })

      err = block_run do |http|

        log("[sms_send] => /rest/Sms/Send  #{pr}")

        res  = http.post("/rest/Sms/Send", pr)
        data = ::JSON.parse(res.body) rescue  (res.body || "").gsub('"', '')

        log("[sms_send] <= #{data}")

      end # block_run

      return err  if err
      return data unless data.is_a?(::Hash)

      case data["Code"]

        when 1 then ::IbateleSms::SessionIdError.new(data["Desc"])
        when 2 then ::IbateleSms::ArgumentError.new(data["Desc"])
        when 4 then ::IbateleSms::SessionExpiredError.new(data["Desc"])
        when 6 then ::IbateleSms::SourceAddressError.new(data["Desc"])
        when 8 then ::IbateleSms::SendingError.new(data["Desc"])
        else        ::IbateleSms::UnknownError.new(data["Desc"])

      end # case

    end # sms_send

    def balance(sid)

      data  = ""
      pr    = ::URI.encode_www_form({

        sessionId: sid

      })

      err = block_run do |http|

        log("[balance] => /rest/User/Balance?#{pr}")

        res  = http.get("/rest/User/Balance?#{pr}")
        data = (res.body || "").to_f

        log("[balance] <= #{data}")

      end # block_run

      return err  if err
      data

    end # balance

    def sms_state(sid, mid)

      data  = ""
      pr    = ::URI.encode_www_form({

        sessionId: sid,
        messageId: mid

      })

      err = block_run do |http|

        log("[sms_state] => /rest/Sms/State?#{pr}")

        res  = http.get("/rest/Sms/State?#{pr}")
        data = ::JSON.parse(res.body) rescue {}

        log("[sms_state] <= #{data}")

      end # block_run

      return err  if err
      return ::IbateleSms::ArgumentError.new(data["Desc"]) if data["Code"] == 1
      data

    end # sms_state

    def sms_stats(sid, start, stop)

      data  = ""
      pr    = ::URI.encode_www_form({

        sessionId:      sid,
        startDateTime:  start,
        endDateTime:    stop

      })

      err = block_run do |http|

        log("[sms_stats] => /rest/Sms/Statistics?#{pr}")

        res  = http.get("/rest/Sms/Statistics?#{pr}")
        data = ::JSON.parse(res.body) rescue {}

        log("[sms_stats] <= #{data}")

      end # block_run

      return err  if err
      return data if data["Code"].nil?

      case data["Code"]

        when 1 then ::IbateleSms::SessionIdError.new(data["Desc"])
        when 2 then ::IbateleSms::ArgumentError.new(data["Desc"])
        when 9 then ::IbateleSms::ArgumentError.new(data["Desc"])
        else        ::IbateleSms::UnknownError.new(data["Desc"])

      end # case

    end # sms_stats

    private

    def log(msg)

      puts(msg) if ::IbateleSms.debug?
      self

    end # log

    def block_run

      error     = false
      try_count = ::IbateleSms::RETRY

      begin

        ::Timeout::timeout(::IbateleSms::TIMEOUT) {

          ::Net::HTTP.start(
            ::IbateleSms::HOST,
            ::IbateleSms::PORT,
            :use_ssl => ::IbateleSms::USE_SSL
          ) do |http|
              yield(http)
          end

        }

      rescue ::Errno::ECONNREFUSED

        if try_count > 0
          try_count -= 1
          sleep ::IbateleSms::WAIT_TIME
          retry
        else
          error = ::IbateleSms::ConnectionError.new("Прервано соедиение с сервером")
        end

      rescue ::Timeout::Error

        if try_count > 0
          try_count -= 1
          sleep ::IbateleSms::WAIT_TIME
          retry
        else
          error = ::IbateleSms::TimeoutError.new("Превышен интервал ожидания #{::IbateleSms::TIMEOUT} сек. после #{::IbateleSms::RETRY} попыток")
        end

      rescue => e
        error = ::IbateleSms::UnknownError.new(e.message)
      end

      error

    end # block_run

  end # Base

end # IbateleSms
