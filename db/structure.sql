SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: notification_events_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_events_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'notification_events es append-only';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    name character varying NOT NULL,
    country character varying(2) NOT NULL,
    time_zone character varying DEFAULT 'America/Santiago'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employees (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying,
    phone character varying,
    time_zone character varying,
    birth_date date,
    notification_opt_outs jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: notification_channel_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_channel_settings (
    id bigint NOT NULL,
    company_id bigint,
    channel character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_channel_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_channel_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_channel_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_channel_settings_id_seq OWNED BY public.notification_channel_settings.id;


--
-- Name: notification_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_counters (
    id bigint NOT NULL,
    recipient_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    bucket_date date NOT NULL,
    category character varying NOT NULL,
    count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_counters_id_seq OWNED BY public.notification_counters.id;


--
-- Name: notification_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_deliveries (
    id uuid DEFAULT uuidv7() NOT NULL,
    request_id uuid NOT NULL,
    company_id bigint NOT NULL,
    notification_key character varying NOT NULL,
    category character varying NOT NULL,
    recipient_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    channel character varying NOT NULL,
    address text,
    provider character varying,
    provider_message_id character varying,
    subject text,
    body_text text,
    content_hash character varying,
    html_ref character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    decision_reason jsonb DEFAULT '{}'::jsonb NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_error text,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: notification_deliveries_2026_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_deliveries_2026_10 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_deliveries_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_deliveries_request_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_deliveries_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_deliveries_notification_key_not_null NOT NULL,
    category character varying CONSTRAINT notification_deliveries_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_deliveries_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_deliveries_recipient_id_not_null NOT NULL,
    channel character varying CONSTRAINT notification_deliveries_channel_not_null NOT NULL,
    address text,
    provider character varying,
    provider_message_id character varying,
    subject text,
    body_text text,
    content_hash character varying,
    html_ref character varying,
    status character varying DEFAULT 'pending'::character varying CONSTRAINT notification_deliveries_status_not_null NOT NULL,
    decision_reason jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_deliveries_decision_reason_not_null NOT NULL,
    attempts integer DEFAULT 0 CONSTRAINT notification_deliveries_attempts_not_null NOT NULL,
    last_error text,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_deliveries_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_deliveries_updated_at_not_null NOT NULL
);


--
-- Name: notification_deliveries_2026_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_deliveries_2026_11 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_deliveries_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_deliveries_request_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_deliveries_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_deliveries_notification_key_not_null NOT NULL,
    category character varying CONSTRAINT notification_deliveries_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_deliveries_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_deliveries_recipient_id_not_null NOT NULL,
    channel character varying CONSTRAINT notification_deliveries_channel_not_null NOT NULL,
    address text,
    provider character varying,
    provider_message_id character varying,
    subject text,
    body_text text,
    content_hash character varying,
    html_ref character varying,
    status character varying DEFAULT 'pending'::character varying CONSTRAINT notification_deliveries_status_not_null NOT NULL,
    decision_reason jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_deliveries_decision_reason_not_null NOT NULL,
    attempts integer DEFAULT 0 CONSTRAINT notification_deliveries_attempts_not_null NOT NULL,
    last_error text,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_deliveries_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_deliveries_updated_at_not_null NOT NULL
);


--
-- Name: notification_deliveries_2026_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_deliveries_2026_12 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_deliveries_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_deliveries_request_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_deliveries_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_deliveries_notification_key_not_null NOT NULL,
    category character varying CONSTRAINT notification_deliveries_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_deliveries_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_deliveries_recipient_id_not_null NOT NULL,
    channel character varying CONSTRAINT notification_deliveries_channel_not_null NOT NULL,
    address text,
    provider character varying,
    provider_message_id character varying,
    subject text,
    body_text text,
    content_hash character varying,
    html_ref character varying,
    status character varying DEFAULT 'pending'::character varying CONSTRAINT notification_deliveries_status_not_null NOT NULL,
    decision_reason jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_deliveries_decision_reason_not_null NOT NULL,
    attempts integer DEFAULT 0 CONSTRAINT notification_deliveries_attempts_not_null NOT NULL,
    last_error text,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_deliveries_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_deliveries_updated_at_not_null NOT NULL
);


--
-- Name: notification_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    request_id uuid NOT NULL,
    delivery_id uuid,
    event_type character varying NOT NULL,
    provider_event_id character varying,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: notification_events_2026_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_events_2026_10 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_events_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_events_request_id_not_null NOT NULL,
    delivery_id uuid,
    event_type character varying CONSTRAINT notification_events_event_type_not_null NOT NULL,
    provider_event_id character varying,
    payload jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_events_payload_not_null NOT NULL,
    occurred_at timestamp(6) without time zone CONSTRAINT notification_events_occurred_at_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT notification_events_created_at_not_null NOT NULL
);


--
-- Name: notification_events_2026_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_events_2026_11 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_events_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_events_request_id_not_null NOT NULL,
    delivery_id uuid,
    event_type character varying CONSTRAINT notification_events_event_type_not_null NOT NULL,
    provider_event_id character varying,
    payload jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_events_payload_not_null NOT NULL,
    occurred_at timestamp(6) without time zone CONSTRAINT notification_events_occurred_at_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT notification_events_created_at_not_null NOT NULL
);


--
-- Name: notification_events_2026_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_events_2026_12 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_events_id_not_null NOT NULL,
    request_id uuid CONSTRAINT notification_events_request_id_not_null NOT NULL,
    delivery_id uuid,
    event_type character varying CONSTRAINT notification_events_event_type_not_null NOT NULL,
    provider_event_id character varying,
    payload jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_events_payload_not_null NOT NULL,
    occurred_at timestamp(6) without time zone CONSTRAINT notification_events_occurred_at_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT notification_events_created_at_not_null NOT NULL
);


--
-- Name: notification_history_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_history_accesses (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    user_id bigint NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    viewed_request_id uuid,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_history_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_history_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_history_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_history_accesses_id_seq OWNED BY public.notification_history_accesses.id;


--
-- Name: notification_idempotency_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_idempotency_keys (
    id bigint NOT NULL,
    notification_key character varying NOT NULL,
    recipient_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    idempotency_key character varying NOT NULL,
    request_id uuid NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_idempotency_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_idempotency_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_idempotency_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_idempotency_keys_id_seq OWNED BY public.notification_idempotency_keys.id;


--
-- Name: notification_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_requests (
    id uuid DEFAULT uuidv7() NOT NULL,
    company_id bigint NOT NULL,
    notification_key character varying NOT NULL,
    notification_version integer DEFAULT 1 NOT NULL,
    category character varying NOT NULL,
    recipient_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    origin jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying NOT NULL,
    status character varying DEFAULT 'accepted'::character varying NOT NULL,
    status_reason character varying,
    scheduled_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: notification_requests_2026_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_requests_2026_10 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_requests_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_requests_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_requests_notification_key_not_null NOT NULL,
    notification_version integer DEFAULT 1 CONSTRAINT notification_requests_notification_version_not_null NOT NULL,
    category character varying CONSTRAINT notification_requests_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_requests_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_requests_recipient_id_not_null NOT NULL,
    params jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_params_not_null NOT NULL,
    origin jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_origin_not_null NOT NULL,
    idempotency_key character varying CONSTRAINT notification_requests_idempotency_key_not_null NOT NULL,
    status character varying DEFAULT 'accepted'::character varying CONSTRAINT notification_requests_status_not_null NOT NULL,
    status_reason character varying,
    scheduled_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_requests_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_requests_updated_at_not_null NOT NULL
);


--
-- Name: notification_requests_2026_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_requests_2026_11 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_requests_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_requests_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_requests_notification_key_not_null NOT NULL,
    notification_version integer DEFAULT 1 CONSTRAINT notification_requests_notification_version_not_null NOT NULL,
    category character varying CONSTRAINT notification_requests_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_requests_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_requests_recipient_id_not_null NOT NULL,
    params jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_params_not_null NOT NULL,
    origin jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_origin_not_null NOT NULL,
    idempotency_key character varying CONSTRAINT notification_requests_idempotency_key_not_null NOT NULL,
    status character varying DEFAULT 'accepted'::character varying CONSTRAINT notification_requests_status_not_null NOT NULL,
    status_reason character varying,
    scheduled_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_requests_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_requests_updated_at_not_null NOT NULL
);


--
-- Name: notification_requests_2026_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_requests_2026_12 (
    id uuid DEFAULT uuidv7() CONSTRAINT notification_requests_id_not_null NOT NULL,
    company_id bigint CONSTRAINT notification_requests_company_id_not_null NOT NULL,
    notification_key character varying CONSTRAINT notification_requests_notification_key_not_null NOT NULL,
    notification_version integer DEFAULT 1 CONSTRAINT notification_requests_notification_version_not_null NOT NULL,
    category character varying CONSTRAINT notification_requests_category_not_null NOT NULL,
    recipient_type character varying CONSTRAINT notification_requests_recipient_type_not_null NOT NULL,
    recipient_id bigint CONSTRAINT notification_requests_recipient_id_not_null NOT NULL,
    params jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_params_not_null NOT NULL,
    origin jsonb DEFAULT '{}'::jsonb CONSTRAINT notification_requests_origin_not_null NOT NULL,
    idempotency_key character varying CONSTRAINT notification_requests_idempotency_key_not_null NOT NULL,
    status character varying DEFAULT 'accepted'::character varying CONSTRAINT notification_requests_status_not_null NOT NULL,
    status_reason character varying,
    scheduled_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone CONSTRAINT notification_requests_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT notification_requests_updated_at_not_null NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: solid_queue_batch_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_batch_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    batch_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_batch_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_batch_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_batch_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_batch_executions_id_seq OWNED BY public.solid_queue_batch_executions.id;


--
-- Name: solid_queue_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_batches (
    id bigint NOT NULL,
    active_job_batch_id character varying,
    description character varying,
    on_finish text,
    on_success text,
    on_failure text,
    metadata text,
    total_jobs integer DEFAULT 0 NOT NULL,
    completed_jobs integer DEFAULT 0 NOT NULL,
    failed_jobs integer DEFAULT 0 NOT NULL,
    enqueued_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_batches_id_seq OWNED BY public.solid_queue_batches.id;


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    batch_id bigint
);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: notification_deliveries_2026_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries ATTACH PARTITION public.notification_deliveries_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');


--
-- Name: notification_deliveries_2026_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries ATTACH PARTITION public.notification_deliveries_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');


--
-- Name: notification_deliveries_2026_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries ATTACH PARTITION public.notification_deliveries_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: notification_events_2026_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events ATTACH PARTITION public.notification_events_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');


--
-- Name: notification_events_2026_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events ATTACH PARTITION public.notification_events_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');


--
-- Name: notification_events_2026_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events ATTACH PARTITION public.notification_events_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: notification_requests_2026_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests ATTACH PARTITION public.notification_requests_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');


--
-- Name: notification_requests_2026_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests ATTACH PARTITION public.notification_requests_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');


--
-- Name: notification_requests_2026_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests ATTACH PARTITION public.notification_requests_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: notification_channel_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_channel_settings ALTER COLUMN id SET DEFAULT nextval('public.notification_channel_settings_id_seq'::regclass);


--
-- Name: notification_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_counters ALTER COLUMN id SET DEFAULT nextval('public.notification_counters_id_seq'::regclass);


--
-- Name: notification_history_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_history_accesses ALTER COLUMN id SET DEFAULT nextval('public.notification_history_accesses_id_seq'::regclass);


--
-- Name: notification_idempotency_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_idempotency_keys ALTER COLUMN id SET DEFAULT nextval('public.notification_idempotency_keys_id_seq'::regclass);


--
-- Name: solid_queue_batch_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_batch_executions_id_seq'::regclass);


--
-- Name: solid_queue_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batches ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_batches_id_seq'::regclass);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: notification_channel_settings notification_channel_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_channel_settings
    ADD CONSTRAINT notification_channel_settings_pkey PRIMARY KEY (id);


--
-- Name: notification_counters notification_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_counters
    ADD CONSTRAINT notification_counters_pkey PRIMARY KEY (id);


--
-- Name: notification_deliveries notification_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries
    ADD CONSTRAINT notification_deliveries_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_deliveries_2026_10 notification_deliveries_2026_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries_2026_10
    ADD CONSTRAINT notification_deliveries_2026_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_deliveries_2026_11 notification_deliveries_2026_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries_2026_11
    ADD CONSTRAINT notification_deliveries_2026_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_deliveries_2026_12 notification_deliveries_2026_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_deliveries_2026_12
    ADD CONSTRAINT notification_deliveries_2026_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_events notification_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events
    ADD CONSTRAINT notification_events_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_events_2026_10 notification_events_2026_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events_2026_10
    ADD CONSTRAINT notification_events_2026_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_events_2026_11 notification_events_2026_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events_2026_11
    ADD CONSTRAINT notification_events_2026_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_events_2026_12 notification_events_2026_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events_2026_12
    ADD CONSTRAINT notification_events_2026_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_history_accesses notification_history_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_history_accesses
    ADD CONSTRAINT notification_history_accesses_pkey PRIMARY KEY (id);


--
-- Name: notification_idempotency_keys notification_idempotency_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_idempotency_keys
    ADD CONSTRAINT notification_idempotency_keys_pkey PRIMARY KEY (id);


--
-- Name: notification_requests notification_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests
    ADD CONSTRAINT notification_requests_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_requests_2026_10 notification_requests_2026_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests_2026_10
    ADD CONSTRAINT notification_requests_2026_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_requests_2026_11 notification_requests_2026_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests_2026_11
    ADD CONSTRAINT notification_requests_2026_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: notification_requests_2026_12 notification_requests_2026_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_requests_2026_12
    ADD CONSTRAINT notification_requests_2026_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: solid_queue_batch_executions solid_queue_batch_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT solid_queue_batch_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_batches solid_queue_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batches
    ADD CONSTRAINT solid_queue_batches_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_notification_channel_settings_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_notification_channel_settings_unique ON public.notification_channel_settings USING btree (company_id, channel) NULLS NOT DISTINCT;


--
-- Name: idx_notification_counters_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_notification_counters_unique ON public.notification_counters USING btree (recipient_type, recipient_id, bucket_date, category);


--
-- Name: idx_notification_deliveries_cooldown; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_deliveries_cooldown ON ONLY public.notification_deliveries USING btree (recipient_type, recipient_id, notification_key, created_at);


--
-- Name: idx_notification_deliveries_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_deliveries_key ON ONLY public.notification_deliveries USING btree (company_id, notification_key, created_at);


--
-- Name: idx_notification_deliveries_recipient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_deliveries_recipient ON ONLY public.notification_deliveries USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: idx_notification_idempotency_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_notification_idempotency_unique ON public.notification_idempotency_keys USING btree (notification_key, recipient_type, recipient_id, idempotency_key);


--
-- Name: idx_notification_requests_recipient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_requests_recipient ON ONLY public.notification_requests USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: idx_on_company_id_created_at_d4d7c8f294; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_company_id_created_at_d4d7c8f294 ON public.notification_history_accesses USING btree (company_id, created_at);


--
-- Name: index_employees_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employees_on_company_id ON public.employees USING btree (company_id);


--
-- Name: index_employees_on_company_id_and_birth_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employees_on_company_id_and_birth_date ON public.employees USING btree (company_id, birth_date);


--
-- Name: index_notification_counters_on_bucket_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_counters_on_bucket_date ON public.notification_counters USING btree (bucket_date);


--
-- Name: index_notification_deliveries_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_deliveries_on_request_id ON ONLY public.notification_deliveries USING btree (request_id);


--
-- Name: index_notification_events_on_delivery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_events_on_delivery_id ON ONLY public.notification_events USING btree (delivery_id);


--
-- Name: index_notification_events_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_events_on_request_id ON ONLY public.notification_events USING btree (request_id);


--
-- Name: index_notification_history_accesses_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_history_accesses_on_company_id ON public.notification_history_accesses USING btree (company_id);


--
-- Name: index_notification_history_accesses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_history_accesses_on_user_id ON public.notification_history_accesses USING btree (user_id);


--
-- Name: index_notification_idempotency_keys_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_idempotency_keys_on_expires_at ON public.notification_idempotency_keys USING btree (expires_at);


--
-- Name: index_notification_requests_on_status_and_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_requests_on_status_and_scheduled_at ON ONLY public.notification_requests USING btree (status, scheduled_at);


--
-- Name: index_solid_queue_batch_executions_on_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_batch_executions_on_batch_id ON public.solid_queue_batch_executions USING btree (batch_id);


--
-- Name: index_solid_queue_batch_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_batch_executions_on_job_id ON public.solid_queue_batch_executions USING btree (job_id);


--
-- Name: index_solid_queue_batches_on_active_job_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_batches_on_active_job_batch_id ON public.solid_queue_batches USING btree (active_job_batch_id);


--
-- Name: index_solid_queue_batches_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_batches_on_finished_at ON public.solid_queue_batches USING btree (finished_at);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_batch_id ON public.solid_queue_jobs USING btree (batch_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_users_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_company_id ON public.users USING btree (company_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: notification_deliveries_2026_10_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026_10_request_id_idx ON public.notification_deliveries_2026_10 USING btree (request_id);


--
-- Name: notification_deliveries_2026_11_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026_11_request_id_idx ON public.notification_deliveries_2026_11 USING btree (request_id);


--
-- Name: notification_deliveries_2026_12_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026_12_request_id_idx ON public.notification_deliveries_2026_12 USING btree (request_id);


--
-- Name: notification_deliveries_2026__company_id_notification_key__idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_notification_key__idx1 ON public.notification_deliveries_2026_11 USING btree (company_id, notification_key, created_at);


--
-- Name: notification_deliveries_2026__company_id_notification_key__idx2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_notification_key__idx2 ON public.notification_deliveries_2026_12 USING btree (company_id, notification_key, created_at);


--
-- Name: notification_deliveries_2026__company_id_notification_key_c_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_notification_key_c_idx ON public.notification_deliveries_2026_10 USING btree (company_id, notification_key, created_at);


--
-- Name: notification_deliveries_2026__company_id_recipient_type_re_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_recipient_type_re_idx1 ON public.notification_deliveries_2026_11 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_deliveries_2026__company_id_recipient_type_re_idx2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_recipient_type_re_idx2 ON public.notification_deliveries_2026_12 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_deliveries_2026__company_id_recipient_type_rec_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__company_id_recipient_type_rec_idx ON public.notification_deliveries_2026_10 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id__idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__recipient_type_recipient_id__idx1 ON public.notification_deliveries_2026_11 USING btree (recipient_type, recipient_id, notification_key, created_at);


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id__idx2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__recipient_type_recipient_id__idx2 ON public.notification_deliveries_2026_12 USING btree (recipient_type, recipient_id, notification_key, created_at);


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id_n_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_deliveries_2026__recipient_type_recipient_id_n_idx ON public.notification_deliveries_2026_10 USING btree (recipient_type, recipient_id, notification_key, created_at);


--
-- Name: notification_events_2026_10_delivery_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_10_delivery_id_idx ON public.notification_events_2026_10 USING btree (delivery_id);


--
-- Name: notification_events_2026_10_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_10_request_id_idx ON public.notification_events_2026_10 USING btree (request_id);


--
-- Name: notification_events_2026_11_delivery_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_11_delivery_id_idx ON public.notification_events_2026_11 USING btree (delivery_id);


--
-- Name: notification_events_2026_11_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_11_request_id_idx ON public.notification_events_2026_11 USING btree (request_id);


--
-- Name: notification_events_2026_12_delivery_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_12_delivery_id_idx ON public.notification_events_2026_12 USING btree (delivery_id);


--
-- Name: notification_events_2026_12_request_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_events_2026_12_request_id_idx ON public.notification_events_2026_12 USING btree (request_id);


--
-- Name: notification_requests_2026_10_company_id_recipient_type_rec_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_10_company_id_recipient_type_rec_idx ON public.notification_requests_2026_10 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_requests_2026_10_status_scheduled_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_10_status_scheduled_at_idx ON public.notification_requests_2026_10 USING btree (status, scheduled_at);


--
-- Name: notification_requests_2026_11_company_id_recipient_type_rec_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_11_company_id_recipient_type_rec_idx ON public.notification_requests_2026_11 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_requests_2026_11_status_scheduled_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_11_status_scheduled_at_idx ON public.notification_requests_2026_11 USING btree (status, scheduled_at);


--
-- Name: notification_requests_2026_12_company_id_recipient_type_rec_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_12_company_id_recipient_type_rec_idx ON public.notification_requests_2026_12 USING btree (company_id, recipient_type, recipient_id, created_at);


--
-- Name: notification_requests_2026_12_status_scheduled_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_requests_2026_12_status_scheduled_at_idx ON public.notification_requests_2026_12 USING btree (status, scheduled_at);


--
-- Name: notification_deliveries_2026_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_deliveries_pkey ATTACH PARTITION public.notification_deliveries_2026_10_pkey;


--
-- Name: notification_deliveries_2026_10_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_deliveries_on_request_id ATTACH PARTITION public.notification_deliveries_2026_10_request_id_idx;


--
-- Name: notification_deliveries_2026_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_deliveries_pkey ATTACH PARTITION public.notification_deliveries_2026_11_pkey;


--
-- Name: notification_deliveries_2026_11_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_deliveries_on_request_id ATTACH PARTITION public.notification_deliveries_2026_11_request_id_idx;


--
-- Name: notification_deliveries_2026_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_deliveries_pkey ATTACH PARTITION public.notification_deliveries_2026_12_pkey;


--
-- Name: notification_deliveries_2026_12_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_deliveries_on_request_id ATTACH PARTITION public.notification_deliveries_2026_12_request_id_idx;


--
-- Name: notification_deliveries_2026__company_id_notification_key__idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_key ATTACH PARTITION public.notification_deliveries_2026__company_id_notification_key__idx1;


--
-- Name: notification_deliveries_2026__company_id_notification_key__idx2; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_key ATTACH PARTITION public.notification_deliveries_2026__company_id_notification_key__idx2;


--
-- Name: notification_deliveries_2026__company_id_notification_key_c_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_key ATTACH PARTITION public.notification_deliveries_2026__company_id_notification_key_c_idx;


--
-- Name: notification_deliveries_2026__company_id_recipient_type_re_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_recipient ATTACH PARTITION public.notification_deliveries_2026__company_id_recipient_type_re_idx1;


--
-- Name: notification_deliveries_2026__company_id_recipient_type_re_idx2; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_recipient ATTACH PARTITION public.notification_deliveries_2026__company_id_recipient_type_re_idx2;


--
-- Name: notification_deliveries_2026__company_id_recipient_type_rec_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_recipient ATTACH PARTITION public.notification_deliveries_2026__company_id_recipient_type_rec_idx;


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id__idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_cooldown ATTACH PARTITION public.notification_deliveries_2026__recipient_type_recipient_id__idx1;


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id__idx2; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_cooldown ATTACH PARTITION public.notification_deliveries_2026__recipient_type_recipient_id__idx2;


--
-- Name: notification_deliveries_2026__recipient_type_recipient_id_n_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_deliveries_cooldown ATTACH PARTITION public.notification_deliveries_2026__recipient_type_recipient_id_n_idx;


--
-- Name: notification_events_2026_10_delivery_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_delivery_id ATTACH PARTITION public.notification_events_2026_10_delivery_id_idx;


--
-- Name: notification_events_2026_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_events_pkey ATTACH PARTITION public.notification_events_2026_10_pkey;


--
-- Name: notification_events_2026_10_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_request_id ATTACH PARTITION public.notification_events_2026_10_request_id_idx;


--
-- Name: notification_events_2026_11_delivery_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_delivery_id ATTACH PARTITION public.notification_events_2026_11_delivery_id_idx;


--
-- Name: notification_events_2026_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_events_pkey ATTACH PARTITION public.notification_events_2026_11_pkey;


--
-- Name: notification_events_2026_11_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_request_id ATTACH PARTITION public.notification_events_2026_11_request_id_idx;


--
-- Name: notification_events_2026_12_delivery_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_delivery_id ATTACH PARTITION public.notification_events_2026_12_delivery_id_idx;


--
-- Name: notification_events_2026_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_events_pkey ATTACH PARTITION public.notification_events_2026_12_pkey;


--
-- Name: notification_events_2026_12_request_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_events_on_request_id ATTACH PARTITION public.notification_events_2026_12_request_id_idx;


--
-- Name: notification_requests_2026_10_company_id_recipient_type_rec_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_requests_recipient ATTACH PARTITION public.notification_requests_2026_10_company_id_recipient_type_rec_idx;


--
-- Name: notification_requests_2026_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_requests_pkey ATTACH PARTITION public.notification_requests_2026_10_pkey;


--
-- Name: notification_requests_2026_10_status_scheduled_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_requests_on_status_and_scheduled_at ATTACH PARTITION public.notification_requests_2026_10_status_scheduled_at_idx;


--
-- Name: notification_requests_2026_11_company_id_recipient_type_rec_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_requests_recipient ATTACH PARTITION public.notification_requests_2026_11_company_id_recipient_type_rec_idx;


--
-- Name: notification_requests_2026_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_requests_pkey ATTACH PARTITION public.notification_requests_2026_11_pkey;


--
-- Name: notification_requests_2026_11_status_scheduled_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_requests_on_status_and_scheduled_at ATTACH PARTITION public.notification_requests_2026_11_status_scheduled_at_idx;


--
-- Name: notification_requests_2026_12_company_id_recipient_type_rec_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_notification_requests_recipient ATTACH PARTITION public.notification_requests_2026_12_company_id_recipient_type_rec_idx;


--
-- Name: notification_requests_2026_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.notification_requests_pkey ATTACH PARTITION public.notification_requests_2026_12_pkey;


--
-- Name: notification_requests_2026_12_status_scheduled_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_notification_requests_on_status_and_scheduled_at ATTACH PARTITION public.notification_requests_2026_12_status_scheduled_at_idx;


--
-- Name: notification_events notification_events_no_update_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notification_events_no_update_delete BEFORE DELETE OR UPDATE ON public.notification_events FOR EACH ROW EXECUTE FUNCTION public.notification_events_immutable();


--
-- Name: employees fk_rails_15ca1438d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT fk_rails_15ca1438d5 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: notification_history_accesses fk_rails_4c0d8d8fc5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_history_accesses
    ADD CONSTRAINT fk_rails_4c0d8d8fc5 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: users fk_rails_7682a3bdfe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_7682a3bdfe FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: solid_queue_batch_executions fk_rails_7c5e073422; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT fk_rails_7c5e073422 FOREIGN KEY (batch_id) REFERENCES public.solid_queue_batches(id) ON DELETE CASCADE;


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_batch_executions fk_rails_bc9f981155; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT fk_rails_bc9f981155 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: notification_channel_settings fk_rails_c9790bd9e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_channel_settings
    ADD CONSTRAINT fk_rails_c9790bd9e1 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: notification_history_accesses fk_rails_d23a033bd0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_history_accesses
    ADD CONSTRAINT fk_rails_d23a033bd0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261016000001'),
('20261015000009'),
('20261015000008'),
('20261015000007'),
('20261015000006'),
('20261015000005'),
('20261015000004'),
('20261015000003'),
('20261015000002'),
('20261015000001');

